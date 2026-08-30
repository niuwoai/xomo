import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoFigmaImportTransactionTests {
    enum Editing: CaseIterable {
        case move, duplicateMove, resize, rotate, guide, pathAnchor, penPath
        case gradientCenter, gradientAxis, gradientStop, gradientMidpoint
    }

    @Test(arguments: Editing.allCases)
    func importWaitsForEditingWithoutChangingItsSnapshot(editing: Editing) throws {
        let model = makeModel()
        let plan = try importPlan()
        try begin(editing, in: model)
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        let redoCount = model.redoStack.count
        let selectedID = model.document.selectedLayerID

        #expect(!model.canImportFigmaNodePlan)
        #expect(!model.importFigmaNodePlan(plan))
        #expect(try model.projectData() == before)
        #expect(model.undoStack.count == undoCount)
        #expect(model.redoStack.count == redoCount)
        #expect(model.document.selectedLayerID == selectedID)
        #expect(model.statusText == model.figmaImportEditingInProgressMessage)

        finish(editing, in: model)
        #expect(model.canImportFigmaNodePlan)
        let finished = try model.projectData()
        let finishedUndoCount = model.undoStack.count
        #expect(model.importFigmaNodePlan(plan))
        let importedID = try #require(model.document.selectedLayerID)
        #expect(model.undoStack.count == finishedUndoCount + 1)
        model.undo()
        #expect(try model.projectData() == finished)
        model.redo()
        #expect(model.document.selectedLayerID == importedID)
        #expect(model.document.selectedLayer?.name == "Imported")
    }

    @Test func pendingPenRedoAlsoOwnsTheEditingContext() throws {
        let model = makeModel()
        model.selectTool(.pen)
        model.addPenPoint(CGPoint(x: 20, y: 20))
        #expect(model.undoPendingPenPoint())
        #expect(model.pendingPenPathAnchors.isEmpty)
        #expect(model.hasPendingPenPathTransaction)
        #expect(!model.canImportFigmaNodePlan)
        #expect(!model.importFigmaNodePlan(try importPlan()))
        #expect(model.redoPendingPenPoint())
        #expect(model.pendingPenPathAnchors.count == 1)
        #expect(model.cancelPenPath())
        #expect(model.canImportFigmaNodePlan)
    }

    @Test func finishingMovedLayerKeepsMoveAndImportAsSeparateUndoSteps() throws {
        let model = makeModel()
        let original = try model.projectData()
        #expect(model.beginMovingSelectedLayer())
        model.moveSelectedLayer(by: CGSize(width: 14, height: 9), snapping: false)
        #expect(!model.importFigmaNodePlan(try importPlan()))
        model.finishMovingSelectedLayer()
        let moved = try model.projectData()
        #expect(moved != original)
        #expect(model.importFigmaNodePlan(try importPlan()))
        model.undo()
        #expect(try model.projectData() == moved)
        model.undo()
        #expect(try model.projectData() == original)
    }

    @Test func sliceOnlyPlanCannotMutateAnActiveTransactionEither() throws {
        let model = makeModel()
        var plan = try importPlan()
        plan.items[0].targetKind = .slice
        plan.items[0].sourceType = "SLICE"
        #expect(model.beginDuplicatingSelectedLayerForMove())
        let layerIDs = model.document.layers.map(\.id)
        let undoCount = model.undoStack.count
        #expect(!model.importFigmaNodePlan(plan))
        #expect(model.document.slices.isEmpty)
        #expect(model.document.layers.map(\.id) == layerIDs)
        #expect(model.undoStack.count == undoCount)
        #expect(model.cancelMovingSelectedLayer())
        #expect(model.importFigmaNodePlan(plan))
        #expect(model.document.slices.count == 1)
    }

    @Test func importButtonUsesModelAvailabilityAndBundledLocalizedExplanation() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("veilpic/XomoFigmaLinkImportSheet.swift"), encoding: .utf8)
        #expect(source.contains(".disabled(didImportNodePlan || plan.mappableCount == 0 || !viewModel.canImportFigmaNodePlan)"))
        #expect(source.contains("Label(viewModel.figmaImportEditingInProgressMessage"))
        for language in ["en", "zh-Hans", "ja"] {
            let resource = try #require(Bundle.main.url(forResource: "FigmaImport", withExtension: "strings", subdirectory: nil, localization: language))
            let strings = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: resource), format: nil) as? [String: String])
            #expect(strings["finishEditing"]?.isEmpty == false)
        }
        #expect(makeModel().figmaImportEditingInProgressMessage != "finishEditing")
    }

    private func begin(_ editing: Editing, in model: ImageEditorViewModel) throws {
        let frame = try #require(model.selectedLayerTransformFrame)
        switch editing {
        case .move:
            #expect(model.beginMovingSelectedLayer())
            model.moveSelectedLayer(by: CGSize(width: 8, height: 6), snapping: false)
        case .duplicateMove:
            #expect(model.beginDuplicatingSelectedLayerForMove())
        case .resize:
            model.beginResizingSelectedLayer(handle: .right)
            model.resizeSelectedLayer(to: CGPoint(x: frame.maxX + 10, y: frame.midY), handle: .right)
        case .rotate:
            model.beginRotatingSelectedLayer(from: CGPoint(x: frame.midX, y: frame.minY - 20))
            model.rotateSelectedLayer(to: CGPoint(x: frame.maxX + 20, y: frame.midY))
        case .guide:
            let guide = ImageEditorGuide(orientation: .vertical, position: 20)
            model.document.guides = [guide]
            model.beginMovingGuide(guide.id)
            model.moveGuide(guide.id, to: 24)
        case .pathAnchor:
            model.selectTool(.pen)
            model.addPenPoint(CGPoint(x: 20, y: 20))
            model.addPenPoint(CGPoint(x: 50, y: 40))
            model.finishPenPath(closed: false)
            #expect(model.beginMovingPathAnchor(at: CGPoint(x: 20, y: 20)))
            model.moveSelectedPathAnchor(to: CGPoint(x: 24, y: 22))
        case .penPath:
            model.selectTool(.pen)
            model.addPenPoint(CGPoint(x: 20, y: 20))
        case .gradientCenter:
            #expect(model.beginEditingSelectedLayerGradientOverlayCanvasCenter())
            model.updateSelectedLayerGradientOverlayCanvasCenter(to: CGPoint(x: frame.maxX, y: frame.maxY))
        case .gradientAxis:
            #expect(model.beginEditingSelectedLayerGradientOverlayCanvasAxis())
        case .gradientStop:
            let index = try #require(model.document.selectedLayerIndex)
            model.document.layers[index].style.setGradientOverlayColorStops([
                ImageEditorGradientColorStop(position: 0, color: .black),
                ImageEditorGradientColorStop(position: 0.5, color: .gray),
                ImageEditorGradientColorStop(position: 1, color: .white)
            ])
            try #require(model.beginEditingSelectedLayerGradientOverlayCanvasStop(at: 1))
        case .gradientMidpoint:
            #expect(model.beginEditingSelectedLayerGradientOverlayCanvasMidpoint(after: 0))
        }
    }

    private func finish(_ editing: Editing, in model: ImageEditorViewModel) {
        switch editing {
        case .move, .duplicateMove: #expect(model.cancelMovingSelectedLayer())
        case .resize, .rotate: #expect(model.cancelTransformingSelectedLayer())
        case .guide: model.finishMovingGuide()
        case .pathAnchor: #expect(model.cancelMovingPathAnchor())
        case .penPath: #expect(model.cancelPenPath())
        case .gradientCenter: #expect(model.cancelEditingSelectedLayerGradientOverlayCanvasCenter())
        case .gradientAxis: #expect(model.cancelEditingSelectedLayerGradientOverlayCanvasAxis())
        case .gradientStop: #expect(model.cancelEditingSelectedLayerGradientOverlayCanvasStop())
        case .gradientMidpoint: #expect(model.cancelEditingSelectedLayerGradientOverlayCanvasMidpoint())
        }
    }

    private func makeModel() -> ImageEditorViewModel {
        let size = CGSize(width: 160, height: 120)
        let image = NSImage.rendered(size: size) { rect in
            NSColor.white.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
        let model = ImageEditorViewModel(sourceName: "fixture.png", image: image) { _ in }
        if let index = model.document.selectedLayerIndex {
            // The constructor selects a separate empty edit layer, not the
            // supplied background image. Give that editable layer content.
            model.document.layers[index].image = image
            model.document.layers[index].style.gradientOverlayEnabled = true
        }
        return model
    }

    private func importPlan() throws -> XomoFigmaNodeImportPlan {
        let data = Data(#"""
        {"name":"Fixture","nodes":{"1:3":{"document":{
          "id":"1:3","name":"Imported","type":"RECTANGLE",
          "absoluteBoundingBox":{"x":0,"y":0,"width":20,"height":10}
        }}}}
        """#.utf8)
        return try XomoFigmaNodeImportMapper.makePlan(
            response: JSONDecoder().decode(XomoFigmaNodeResponse.self, from: data),
            requestedNodeID: "1:3"
        )
    }
}
