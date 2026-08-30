import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorGroupMaskTranslationTests {
    @Test(arguments: [false, true], [false, true])
    func dragHonorsGroupMaskLinkageInCanvasCoordinates(linked: Bool, vector: Bool) throws {
        let model = fixture(linked: linked, vector: vector)
        #expect(model.beginMovingSelectedLayer())
        model.moveSelectedLayer(by: CGSize(width: 30, height: 25))
        model.finishMovingSelectedLayer()
        let group = try #require(model.document.layers.first { $0.name == "Masked" })
        #expect(group.frame.origin == CGPoint(x: 50, y: 45))
        let mask = try #require(group.effectiveMask)
        #expect(try alpha(mask, x: linked ? 65 : 35, y: linked ? 55 : 30) > 0.9)
        #expect(try alpha(mask, x: linked ? 35 : 65, y: linked ? 30 : 55) < 0.1)
        #expect(abs(try alpha(model.document.compositedImage, x: 65, y: 55) - (linked ? 1 : 0)) < 0.1)
    }

    @Test func keyboardNudgeUsesTheSameLinkedMaskTranslation() throws {
        let model = fixture()
        model.nudgeSelectionOrSelectedLayer(by: CGSize(width: 30, height: 25))
        #expect(try alpha(model.document.compositedImage, x: 65, y: 55) > 0.9)
        #expect(try alpha(model.document.compositedImage, x: 35, y: 30) < 0.1)
    }

    @Test(arguments: [false, true])
    func stackReflowMovesLinkedNestedGroupMasksOnly(linked: Bool) throws {
        let model = fixture(linked: linked)
        var outer = ImageEditorLayer.group(name: "Outer", size: model.document.canvasSize)
        outer.stackLayout = ImageEditorStackLayout(axis: .horizontal, paddingTop: 45, paddingLeft: 60)
        let index = try #require(model.document.layers.firstIndex { $0.name == "Masked" })
        model.document.layers[index].groupID = outer.id
        model.document.layers.append(outer)
        model.selectLayer(outer.id)
        model.reflowSelectedStackLayout()
        let group = try #require(model.document.layers.first { $0.name == "Masked" })
        #expect(group.frame.origin == CGPoint(x: 60, y: 45))
        let mask = try #require(group.effectiveMask)
        #expect(try alpha(mask, x: linked ? 75 : 35, y: linked ? 55 : 30) > 0.9)
        #expect(try alpha(mask, x: linked ? 35 : 75, y: linked ? 30 : 55) < 0.1)
        model.undo()
        #expect(try alpha(model.document.compositedImage, x: 35, y: 30) > 0.9)
    }

    @Test func cancelledDragDoesNotChangeMaskOrHistory() throws {
        let model = fixture()
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        #expect(model.beginMovingSelectedLayer())
        model.moveSelectedLayer(by: CGSize(width: 30, height: 25))
        #expect(try model.projectData() == before)
        #expect(model.cancelMovingSelectedLayer())
        #expect(try model.projectData() == before)
        #expect(model.undoStack.count == undoCount)
    }

    @Test func translatedMaskSurvivesUndoRedoAndProjectReload() throws {
        let model = fixture()
        let before = try model.projectData()
        #expect(model.beginMovingSelectedLayer())
        model.moveSelectedLayer(by: CGSize(width: 30, height: 25))
        model.finishMovingSelectedLayer()
        let after = try model.projectData()
        model.undo()
        #expect(try model.projectData() == before)
        model.redo()
        #expect(try model.projectData() == after)
        let restored = fixture()
        try restored.loadProjectData(after)
        #expect(try alpha(restored.document.compositedImage, x: 65, y: 55) > 0.9)
    }

    @Test func movingLeafKeepsItsLinkedMaskInLocalCoordinates() throws {
        let model = fixture()
        model.document.layers.removeAll { $0.isGroup }
        model.document.layers[0].groupID = nil
        model.document.layers[0].mask = .opaqueMask(size: model.document.layers[0].image.size)
        model.selectLayer(model.document.layers[0].id)
        model.nudgeSelectionOrSelectedLayer(by: CGSize(width: 30, height: 25))
        #expect(try alpha(model.document.compositedImage, x: 65, y: 55) > 0.9)
        #expect(model.document.layers[0].mask?.size == CGSize(width: 30, height: 20))
    }

    @Test func movingOnlyAChildDoesNotMoveItsParentGroupMask() throws {
        let model = fixture()
        let childID = try #require(model.document.layers.first { !$0.isGroup }?.id)
        model.selectLayer(childID)
        model.nudgeSelectionOrSelectedLayer(by: CGSize(width: 30, height: 25))
        let group = try #require(model.document.layers.first { $0.isGroup })
        #expect(group.frame.origin == CGPoint(x: 20, y: 20))
        #expect(try alpha(#require(group.effectiveMask), x: 35, y: 30) > 0.9)
    }

    @Test func duplicateDragMovesOnlyTheCopiedGroupMask() throws {
        let model = fixture()
        let originalID = try #require(model.document.selectedLayerID)
        #expect(model.beginDuplicatingSelectedLayerForMove())
        let copiedID = try #require(model.document.selectedLayerID)
        #expect(copiedID != originalID)
        model.moveSelectedLayer(by: CGSize(width: 30, height: 25))
        model.finishMovingSelectedLayer()
        let original = try #require(model.document.layers.first { $0.id == originalID })
        let copied = try #require(model.document.layers.first { $0.id == copiedID })
        #expect(original.frame.origin == CGPoint(x: 20, y: 20))
        #expect(copied.frame.origin == CGPoint(x: 50, y: 45))
        #expect(try alpha(#require(original.effectiveMask), x: 35, y: 30) > 0.9)
        #expect(try alpha(#require(copied.effectiveMask), x: 65, y: 55) > 0.9)
    }

    private func fixture(linked: Bool = true, vector: Bool = false) -> ImageEditorViewModel {
        let size = CGSize(width: 100, height: 100)
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: size)) { _ in }
        var group = ImageEditorLayer.group(name: "Masked", size: size)
        group.frame = CGRect(x: 20, y: 20, width: 30, height: 20)
        group.isMaskLinked = linked
        if vector {
            let points = [CGPoint(x: 20, y: 20), CGPoint(x: 50, y: 20), CGPoint(x: 50, y: 40), CGPoint(x: 20, y: 40)]
            group.vectorMask = ImageEditorShapeContent(
                kind: .path, fillColor: .white, fillOpacity: 1,
                strokeColor: .white, strokeWidth: 1, strokeOpacity: 0,
                pathPoints: points, pathAnchors: points.map { ImageEditorPathAnchor(point: $0) }, isPathClosed: true
            ).normalized(size: size)
        } else {
            group.mask = NSImage.rendered(size: size) { _ in
                NSColor.white.setFill()
                CGRect(x: 20, y: 60, width: 30, height: 20).fill()
            }
        }
        var child = ImageEditorLayer.blank(name: "Content", size: CGSize(width: 30, height: 20))
        child.image = NSImage.rendered(size: child.image.size) { rect in
            NSColor.red.setFill()
            rect.fill()
        } ?? child.image
        child.frame = group.frame
        child.groupID = group.id
        model.document.layers = [child, group]
        model.selectLayer(group.id)
        return model
    }

    private func alpha(_ image: NSImage, x: CGFloat, y: CGFloat) throws -> CGFloat {
        try #require(image.color(at: CGPoint(x: x, y: y))).alphaComponent
    }
}
