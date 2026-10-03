import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorDeferredRedoBoundaryTests {
    enum Preview: CaseIterable { case pixelMove, rotation, resize }
    enum Edit: CaseIterable {
        case opacity, fillOpacity, blendIf, maskDensity, maskFeather
        case pathAnchor, shapeGradient, overlayCenter, overlayAxis, overlayStop, overlayMidpoint
    }
    struct Scenario {
        let preview: Preview
        let changed: Bool
    }
    static let scenarios = Preview.allCases.flatMap { preview in
        [false, true].map { Scenario(preview: preview, changed: $0) }
    }

    @Test(arguments: scenarios, Edit.allCases)
    func noOpTransactionCapturesRedoAfterCanvasBoundary(scenario: Scenario, edit: Edit) throws {
        let preview = scenario.preview
        let changed = scenario.changed
        let model = try fixture()
        let theme = model.xomoComponentTheme
        model.selectXomoComponentTheme(.softMobile)
        let pending = try model.projectData()
        model.undo()
        let original = try model.projectData()
        let reference = try fixture()
        reference.document = model.document
        reference.xomoComponentTheme = theme
        try start(preview, changed: changed, in: reference)
        finish(preview, in: reference)
        let expected = try reference.projectData()
        #expect((expected != original) == changed)

        try start(preview, changed: changed, in: model)
        begin(edit, in: model)
        end(edit, in: model)
        #expect(model.pixelSelectionMoveTransaction == nil)
        #expect(!model.hasActiveSelectedLayerTransformTransaction)
        #expect(try model.projectData() == expected)
        #expect(model.undoStack.count == (changed ? 1 : 0))
        #expect(model.redoStack.count == (changed ? 0 : 1))
        model.redo()
        #expect(try model.projectData() == (changed ? expected : pending))
        #expect(model.xomoComponentTheme == (changed ? theme : .softMobile))
        if changed {
            model.undo()
            #expect(try model.projectData() == original)
            model.redo()
            #expect(try model.projectData() == expected)
        }
    }

    @Test(arguments: [false, true])
    func automationSameOpacityCannotRestoreAnObsoleteRedo(changed: Bool) throws {
        let model = try fixture()
        model.selectXomoComponentTheme(.softMobile)
        let pending = try model.projectData()
        model.undo()
        try start(.pixelMove, changed: changed, in: model)
        let reference = try fixture()
        reference.document = model.document
        reference.pixelSelectionMoveTransaction = model.pixelSelectionMoveTransaction
        reference.finishPixelSelectionMove()
        let expected = try reference.projectData()
        let registry = XomoAutomationRegistry.shared
        registry.register(model)
        defer { registry.unregister(model) }
        let response = registry.execute(XomoAutomationWireRequest(token: "test-only", operation: "call",
            name: "xomo.layer.set_opacity", arguments: ["opacity": .number(1)]))
        #expect(response.ok)
        #expect(model.redoStack.count == (changed ? 0 : 1))
        model.redo()
        #expect(try model.projectData() == (changed ? expected : pending))
    }

    @Test(arguments: Preview.allCases, [Edit.opacity, .fillOpacity, .blendIf, .maskDensity, .maskFeather])
    func effectivePropertyEditRemainsAnIndependentUndo(preview: Preview, edit: Edit) throws {
        let model = try fixture()
        let original = try model.projectData()
        let reference = try fixture()
        reference.document = model.document
        try start(preview, changed: true, in: reference)
        finish(preview, in: reference)
        let transformed = try reference.projectData()
        begin(edit, in: reference)
        change(edit, in: reference)
        end(edit, in: reference)
        let expected = try reference.projectData()
        #expect(expected != transformed)

        try start(preview, changed: true, in: model)
        begin(edit, in: model)
        change(edit, in: model)
        end(edit, in: model)
        #expect(try model.projectData() == expected)
        #expect(model.undoStack.count == 2 && model.redoStack.isEmpty)
        model.undo()
        #expect(try model.projectData() == transformed)
        model.undo()
        #expect(try model.projectData() == original)
        model.redo()
        model.redo()
        #expect(try model.projectData() == expected)
    }

    private func fixture() throws -> ImageEditorViewModel {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        let index = try #require(model.document.selectedLayerIndex)
        model.document.layers[index].mask = model.document.layers[index].image
        model.isEditingLayerMask = false
        model.document.isGuideSnappingEnabled = false
        model.clearUndoHistory()
        return model
    }

    private func start(_ preview: Preview, changed: Bool, in model: ImageEditorViewModel) throws {
        let frame = try #require(model.selectedLayerTransformFrame)
        switch preview {
        case .pixelMove:
            try #require(model.beginPixelSelectionMove())
            if changed { model.updatePixelSelectionMove(by: CGSize(width: 3, height: -2)) }
        case .rotation:
            model.beginRotatingSelectedLayer(from: CGPoint(x: frame.midX, y: frame.minY - 24))
            try #require(model.hasActiveSelectedLayerTransformTransaction)
            if changed { model.rotateSelectedLayer(to: CGPoint(x: frame.maxX + 40, y: frame.minY - 40)) }
        case .resize:
            model.beginResizingSelectedLayer(handle: .right)
            try #require(model.hasActiveSelectedLayerTransformTransaction)
            if changed { model.resizeSelectedLayer(to: CGPoint(x: frame.maxX + 40, y: frame.midY), handle: .right) }
        }
    }

    private func finish(_ preview: Preview, in model: ImageEditorViewModel) {
        switch preview {
        case .pixelMove: model.finishPixelSelectionMove()
        case .rotation: model.finishRotatingSelectedLayer()
        case .resize: model.finishResizingSelectedLayer()
        }
    }

    private func begin(_ edit: Edit, in model: ImageEditorViewModel) {
        switch edit {
        case .opacity: model.beginSelectedLayerOpacityChange()
        case .fillOpacity: model.beginSelectedLayerFillOpacityChange()
        case .blendIf: model.beginSelectedLayerBlendIfSourceBlackChange()
        case .maskDensity: model.beginSelectedLayerMaskDensityChange()
        case .maskFeather: model.beginSelectedLayerMaskFeatherChange()
        case .pathAnchor: model.beginPathAnchorMoveUndoTransaction()
        case .shapeGradient: model.beginShapeGradientUndoTransaction()
        case .overlayCenter: model.beginGradientOverlayCenterUndoTransaction()
        case .overlayAxis: model.beginGradientOverlayAxisUndoTransaction()
        case .overlayStop: model.beginGradientOverlayStopUndoTransaction()
        case .overlayMidpoint: model.beginGradientOverlayMidpointUndoTransaction()
        }
    }

    private func change(_ edit: Edit, in model: ImageEditorViewModel) {
        switch edit {
        case .opacity: model.setSelectedLayerOpacity(0.6)
        case .fillOpacity: model.setSelectedLayerFillOpacity(0.6)
        case .blendIf: model.setSelectedLayerBlendIfSourceBlack(0.2)
        case .maskDensity: model.setSelectedLayerMaskDensity(0.6)
        case .maskFeather: model.setSelectedLayerMaskFeather(2)
        default: Issue.record("Only property edits are supported by this fixture")
        }
    }

    private func end(_ edit: Edit, in model: ImageEditorViewModel) {
        switch edit {
        case .opacity: model.commitSelectedLayerOpacityChange()
        case .fillOpacity: model.commitSelectedLayerFillOpacityChange()
        case .blendIf: model.commitSelectedLayerBlendIfChange()
        case .maskDensity: model.commitSelectedLayerMaskDensityChange()
        case .maskFeather: model.commitSelectedLayerMaskFeatherChange()
        case .pathAnchor: model.finishPathAnchorMoveUndoTransaction(didChange: false)
        case .shapeGradient: model.finishShapeGradientUndoTransaction(didChange: false)
        case .overlayCenter: model.finishGradientOverlayCenterUndoTransaction(didChange: false)
        case .overlayAxis: model.finishGradientOverlayAxisUndoTransaction(didChange: false)
        case .overlayStop: model.finishGradientOverlayStopUndoTransaction(didChange: false)
        case .overlayMidpoint: model.finishGradientOverlayMidpointUndoTransaction(didChange: false)
        }
    }
}
