import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorCanvasHandleEditBoundaryTests {
    enum Preview: CaseIterable { case center, axis, stopColor, midpoint, shapeStop, pathAnchor }
    enum Edit: CaseIterable { case rename, theme, rotation }
    struct Scenario { let preview: Preview; let changed: Bool }
    static let scenarios = Preview.allCases.flatMap { preview in
        [false, true].map { Scenario(preview: preview, changed: $0) }
    }

    @Test(arguments: scenarios, Edit.allCases)
    func nextEditCommitsHandlePreviewBeforeItsOwnUndo(scenario: Scenario, edit: Edit) throws {
        let model = try fixture(scenario.preview)
        let originalTheme = model.xomoComponentTheme
        model.selectXomoComponentTheme(.softMobile)
        model.undo()
        let original = try model.projectData()
        let reference = try fixture(scenario.preview)
        reference.document = model.document
        reference.xomoComponentTheme = originalTheme
        try start(scenario, in: reference)
        finish(scenario.preview, in: reference)
        let previewResult = try reference.projectData()
        try #require((previewResult != original) == scenario.changed)
        try apply(edit, in: reference)
        let expected = try reference.projectData()
        try #require(expected != previewResult)

        try start(scenario, in: model)
        try apply(edit, in: model)
        #expect(!active(scenario.preview, in: model))
        #expect(try model.projectData() == expected)
        #expect(model.undoStack.count == (scenario.changed ? 2 : 1))
        #expect(model.redoStack.isEmpty)
        residualEvents(scenario.preview, in: model)
        #expect(try model.projectData() == expected)
        model.undo()
        #expect(try model.projectData() == previewResult)
        #expect(model.xomoComponentTheme == originalTheme)
        if scenario.changed {
            model.undo()
            #expect(try model.projectData() == original)
            model.redo()
            #expect(try model.projectData() == previewResult)
        }
        model.redo()
        #expect(try model.projectData() == expected)
    }

    @Test func automationRenameSurvivesGradientCenterCancellation() throws {
        let model = try fixture(.center)
        let original = try model.projectData()
        try start(Scenario(preview: .center, changed: true), in: model)
        let registry = XomoAutomationRegistry.shared
        registry.register(model)
        defer { registry.unregister(model) }
        let response = registry.execute(XomoAutomationWireRequest(token: "test-only", operation: "call",
            name: "xomo.layer.rename", arguments: ["name": .string("Renamed during gradient drag")]))
        #expect(response.ok)
        let committed = try model.projectData()
        #expect(!model.cancelEditingSelectedLayerGradientOverlayCanvasCenter())
        #expect(model.document.selectedLayer?.name == "Renamed during gradient drag")
        #expect(try model.projectData() == committed)
        model.undo()
        model.undo()
        #expect(try model.projectData() == original)
        model.redo()
        model.redo()
        #expect(try model.projectData() == committed)
    }

    @Test(arguments: Preview.allCases)
    func rejectedCommandsDoNotConsumeHandlePreviewOrRedo(preview: Preview) throws {
        let model = try fixture(preview)
        model.selectXomoComponentTheme(.softMobile)
        let pending = try model.projectData()
        model.undo()
        let name = try #require(model.document.selectedLayer?.name)
        try start(Scenario(preview: preview, changed: false), in: model)
        let displayed = try model.projectData()
        model.renameSelectedLayer(to: name)
        model.renameSelectedLayer(to: "  ")
        model.selectXomoComponentTheme(model.xomoComponentTheme)
        #expect(active(preview, in: model))
        #expect(try model.projectData() == displayed)
        finish(preview, in: model)
        #expect(model.undoStack.isEmpty && model.redoStack.count == 1)
        model.redo()
        #expect(try model.projectData() == pending)
    }

    private func fixture(_ preview: Preview) throws -> ImageEditorViewModel {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        model.document.selection = nil
        model.document.isGuideSnappingEnabled = false
        if preview == .pathAnchor {
            model.selectTool(.pen)
            model.addPenPoint(CGPoint(x: 16, y: 16))
            model.addPenPoint(CGPoint(x: 48, y: 40))
            model.finishPenPath(closed: false)
        } else if preview == .shapeStop {
            model.drawShape(from: CGPoint(x: 8, y: 8), to: CGPoint(x: 56, y: 48), ellipse: false,
                fillGradient: .shapeLinear(colorStops: [
                    ImageEditorGradientColorStop(position: 0, color: .red),
                    ImageEditorGradientColorStop(position: 0.4, color: .green),
                    ImageEditorGradientColorStop(position: 1, color: .blue)
                ]))
        } else {
            let index = try #require(model.document.selectedLayerIndex)
            model.document.layers[index].style.gradientOverlayEnabled = true
            model.document.layers[index].style.gradientOverlayAngle = 0
            model.document.layers[index].style.gradientOverlayCenter = CGPoint(x: 0.5, y: 0.5)
            model.document.layers[index].style.setGradientOverlayColorStops([
                ImageEditorGradientColorStop(position: 0, color: .black),
                ImageEditorGradientColorStop(position: 0.4, color: .green),
                ImageEditorGradientColorStop(position: 1, color: .white)
            ])
        }
        model.clearUndoHistory()
        return model
    }

    private func start(_ scenario: Scenario, in model: ImageEditorViewModel) throws {
        let frame = try #require(model.selectedLayerTransformFrame)
        let point = CGPoint(x: frame.maxX, y: frame.maxY)
        switch scenario.preview {
        case .center:
            try #require(model.beginEditingSelectedLayerGradientOverlayCanvasCenter())
            if scenario.changed { model.updateSelectedLayerGradientOverlayCanvasCenter(to: point) }
        case .axis:
            try #require(model.beginEditingSelectedLayerGradientOverlayCanvasAxis())
            if scenario.changed { model.updateSelectedLayerGradientOverlayCanvasAxis(to: point, snappingAngle: false) }
        case .stopColor:
            try #require(model.beginEditingSelectedLayerGradientOverlayCanvasStopColor(at: 1))
            if scenario.changed { try #require(model.updateSelectedLayerGradientOverlayCanvasStopColor(.orange)) }
        case .midpoint:
            try #require(model.beginEditingSelectedLayerGradientOverlayCanvasMidpoint(after: 0))
            if scenario.changed { model.updateSelectedLayerGradientOverlayCanvasMidpoint(to: point) }
        case .shapeStop:
            try #require(model.beginEditingSelectedShapeGradientStop(at: 1))
            if scenario.changed { model.updateSelectedShapeGradientStop(to: point) }
        case .pathAnchor:
            try #require(model.beginMovingPathAnchor(at: CGPoint(x: 16, y: 16)))
            if scenario.changed { model.moveSelectedPathAnchor(to: CGPoint(x: 20, y: 20)) }
        }
    }

    private func finish(_ preview: Preview, in model: ImageEditorViewModel) {
        switch preview {
        case .center: model.finishEditingSelectedLayerGradientOverlayCanvasCenter()
        case .axis: model.finishEditingSelectedLayerGradientOverlayCanvasAxis()
        case .stopColor: model.finishEditingSelectedLayerGradientOverlayCanvasStop()
        case .midpoint: model.finishEditingSelectedLayerGradientOverlayCanvasMidpoint()
        case .shapeStop: model.finishEditingSelectedShapeGradient()
        case .pathAnchor: model.finishMovingPathAnchor()
        }
    }

    private func active(_ preview: Preview, in model: ImageEditorViewModel) -> Bool {
        switch preview {
        case .center: model.hasActiveGradientOverlayCenterTransaction
        case .axis: model.hasActiveGradientOverlayAxisTransaction
        case .stopColor: model.hasActiveGradientOverlayStopTransaction
        case .midpoint: model.hasActiveGradientOverlayMidpointTransaction
        case .shapeStop: model.editingShapeGradientLayerID != nil
        case .pathAnchor: model.hasActivePathAnchorMoveTransaction
        }
    }

    private func residualEvents(_ preview: Preview, in model: ImageEditorViewModel) {
        let point = CGPoint(x: 2, y: 2)
        switch preview {
        case .center:
            model.updateSelectedLayerGradientOverlayCanvasCenter(to: point)
            _ = model.cancelEditingSelectedLayerGradientOverlayCanvasCenter()
        case .axis:
            model.updateSelectedLayerGradientOverlayCanvasAxis(to: point, snappingAngle: false)
            _ = model.cancelEditingSelectedLayerGradientOverlayCanvasAxis()
        case .stopColor:
            _ = model.updateSelectedLayerGradientOverlayCanvasStopColor(.purple)
            _ = model.cancelEditingSelectedLayerGradientOverlayCanvasStop()
        case .midpoint:
            model.updateSelectedLayerGradientOverlayCanvasMidpoint(to: point)
            _ = model.cancelEditingSelectedLayerGradientOverlayCanvasMidpoint()
        case .shapeStop: model.updateSelectedShapeGradientStop(to: point)
        case .pathAnchor:
            model.moveSelectedPathAnchor(to: point)
            _ = model.cancelMovingPathAnchor()
        }
        finish(preview, in: model)
    }

    private func apply(_ edit: Edit, in model: ImageEditorViewModel) throws {
        switch edit {
        case .rename: model.renameSelectedLayer(to: "Independent rename")
        case .theme: model.selectXomoComponentTheme(.softMobile)
        case .rotation:
            let frame = try #require(model.selectedLayerTransformFrame)
            model.beginRotatingSelectedLayer(from: CGPoint(x: frame.midX, y: frame.minY - 24))
            try #require(model.hasActiveSelectedLayerTransformTransaction)
            model.rotateSelectedLayer(to: CGPoint(x: frame.maxX + 40, y: frame.minY - 40))
            model.finishRotatingSelectedLayer()
        }
    }
}
