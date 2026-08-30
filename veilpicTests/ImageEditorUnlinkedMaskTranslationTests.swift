import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorUnlinkedMaskTranslationTests {
    enum MoveCase: CaseIterable {
        case horizontal, down, up, scaled, nonuniform
        var scale: CGSize {
            switch self {
            case .scaled: CGSize(width: 2, height: 2)
            case .nonuniform: CGSize(width: 2, height: 3)
            default: CGSize(width: 1, height: 1)
            }
        }
        var delta: CGSize {
            switch self {
            case .horizontal: CGSize(width: 10, height: 0)
            case .down: CGSize(width: 0, height: 10)
            case .up: CGSize(width: 0, height: -10)
            case .scaled: CGSize(width: 20, height: 20)
            case .nonuniform: CGSize(width: 20, height: 30)
            }
        }
    }

    @Test(arguments: MoveCase.allCases)
    func unlinkedBitmapMaskStaysFixedAcrossDirectionsAndScales(move: MoveCase) throws {
        let model = fixture(scale: move.scale)
        let before = try pixels(model)
        let frame = try #require(model.document.selectedLayer?.frame)
        #expect(model.beginMovingSelectedLayer())
        model.moveSelectedLayer(by: move.delta)
        model.finishMovingSelectedLayer()
        #expect(model.document.selectedLayer?.frame == frame.offsetBy(dx: move.delta.width, dy: move.delta.height))
        #expect(try pixels(model) == before)
    }

    @Test func vectorMaskKeepsItsExistingTopLeftCoordinateCompensation() throws {
        let model = fixture(scale: CGSize(width: 2, height: 3), vector: true)
        let before = try pixels(model)
        model.nudgeSelectionOrSelectedLayer(by: CGSize(width: 20, height: 30))
        #expect(try pixels(model) == before)
    }

    @Test(arguments: [false, true])
    func automaticLayoutCompensatesUnlinkedLocalMasks(vector: Bool) throws {
        let model = fixture(vector: vector)
        var group = ImageEditorLayer.group(name: "Layout", size: model.document.canvasSize)
        group.stackLayout = ImageEditorStackLayout(axis: .horizontal, paddingTop: 60, paddingLeft: 60)
        model.document.layers[0].groupID = group.id
        model.document.layers.append(group)
        model.selectLayer(group.id)
        let before = try pixels(model)
        model.reflowSelectedStackLayout()
        #expect(model.document.layers[0].frame.origin == CGPoint(x: 60, y: 60))
        #expect(try pixels(model) == before)
        model.undo()
        #expect(model.document.layers[0].frame.origin == CGPoint(x: 40, y: 40))
        #expect(try pixels(model) == before)
    }

    @Test func linkedBitmapMaskStillFollowsItsLayer() throws {
        let model = fixture()
        model.document.layers[0].isMaskLinked = true
        model.nudgeSelectionOrSelectedLayer(by: CGSize(width: 30, height: 20))
        let image = model.document.compositedImage
        #expect(try #require(image.color(at: CGPoint(x: 70, y: 65))).alphaComponent < 0.1)
        #expect(try #require(image.color(at: CGPoint(x: 100, y: 85))).alphaComponent > 0.9)
    }

    @Test func compensatedMaskSurvivesUndoRedoAndProjectReload() throws {
        let model = fixture(scale: CGSize(width: 2, height: 2))
        let before = try model.projectData()
        let originalPixels = try pixels(model)
        model.nudgeSelectionOrSelectedLayer(by: CGSize(width: 20, height: 20))
        let after = try model.projectData()
        model.undo()
        #expect(try model.projectData() == before)
        model.redo()
        #expect(try model.projectData() == after)
        let restored = fixture()
        try restored.loadProjectData(after)
        #expect(try pixels(restored) == originalPixels)
    }

    private func fixture(scale: CGSize = CGSize(width: 1, height: 1), vector: Bool = false) -> ImageEditorViewModel {
        let canvasSize = CGSize(width: 300, height: 300)
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: canvasSize)) { _ in }
        var layer = ImageEditorLayer.blank(name: "Image", size: CGSize(width: 100, height: 80))
        layer.image = NSImage.rendered(size: layer.image.size) { rect in
            NSColor.red.setFill()
            rect.fill()
        } ?? layer.image
        layer.frame = CGRect(x: 40, y: 40, width: 100 * scale.width, height: 80 * scale.height)
        layer.isMaskLinked = false
        if vector {
            let points = [CGPoint(x: 20, y: 20), CGPoint(x: 60, y: 20), CGPoint(x: 60, y: 50), CGPoint(x: 20, y: 50)]
            layer.vectorMask = ImageEditorShapeContent(
                kind: .path, fillColor: .white, fillOpacity: 1,
                strokeColor: .white, strokeWidth: 1, strokeOpacity: 0,
                pathPoints: points, pathAnchors: points.map { ImageEditorPathAnchor(point: $0) }, isPathClosed: true
            )
        } else {
            layer.mask = NSImage.rendered(size: layer.image.size) { _ in
                NSColor.white.setFill()
                CGRect(x: 20, y: 30, width: 40, height: 30).fill()
            }
        }
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        return model
    }

    private func pixels(_ model: ImageEditorViewModel) throws -> Data {
        try #require(model.document.compositedImage.qingtuPNGData())
    }
}
