import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorPixelMoveEditBoundaryTests {
    enum Edit: CaseIterable { case rename, theme, fill, clear, component }

    @Test(arguments: [false, true], Edit.allCases)
    func ordinaryEditFinishesPixelMoveBeforeCapturingItsUndo(changed: Bool, edit: Edit) throws {
        let model = try fixture()
        let originalTheme = model.xomoComponentTheme
        model.selectXomoComponentTheme(.softMobile)
        model.undo()
        let original = try model.projectData()
        let reference = try fixture()
        reference.document = model.document
        reference.xomoComponentTheme = originalTheme
        try #require(reference.projectData() == original)
        try preview(reference, changed: changed)
        reference.finishPixelSelectionMove()
        let moved = try reference.projectData()
        #expect((moved != original) == changed)

        try preview(model, changed: changed)
        apply(edit, to: model)
        #expect(model.pixelSelectionMoveTransaction == nil)
        #expect(model.undoStack.count == (changed ? 2 : 1) && model.redoStack.isEmpty)
        let committed = try model.projectData()
        #expect(committed != moved)
        model.updatePixelSelectionMove(by: CGSize(width: 8, height: 0))
        model.finishPixelSelectionMove()
        model.cancelPixelSelectionMove()
        #expect(try model.projectData() == committed)

        model.undo()
        #expect(try model.projectData() == moved)
        #expect(model.xomoComponentTheme == originalTheme)
        if changed {
            model.undo()
            #expect(try model.projectData() == original)
            model.redo()
            #expect(try model.projectData() == moved)
        }
        model.redo()
        #expect(try model.projectData() == committed)
        #expect(model.undoStack.count == (changed ? 2 : 1) && model.redoStack.isEmpty)
    }

    @Test func rejectedAndUnchangedEditsKeepPixelMoveAndPendingRedo() throws {
        let model = try fixture()
        model.selectXomoComponentTheme(.softMobile)
        let pending = try model.projectData()
        model.undo()
        let original = try model.projectData()
        try preview(model, changed: true)
        let displayed = try model.projectData()
        model.renameSelectedLayer(to: "Move source")
        model.renameSelectedLayer(to: "   ")
        model.selectXomoComponentTheme(model.xomoComponentTheme)
        model.nudgePixelSelection(by: .zero)
        #expect(model.pixelSelectionMoveTransaction != nil)
        #expect(model.undoStack.isEmpty && model.redoStack.count == 1)
        #expect(try model.projectData() == displayed)
        model.cancelPixelSelectionMove()
        #expect(try model.projectData() == original)
        model.redo()
        #expect(try model.projectData() == pending)
    }

    @Test func automationRenameSurvivesEscapeAndResidualPixelMoveEvents() throws {
        let model = try fixture()
        let original = try model.projectData()
        try preview(model, changed: true)
        let registry = XomoAutomationRegistry.shared
        registry.register(model)
        defer { registry.unregister(model) }
        let response = registry.execute(XomoAutomationWireRequest(token: "test-only", operation: "call",
            name: "xomo.layer.rename", arguments: ["name": .string("Renamed during pixel move")]))
        #expect(response.ok && model.document.selectedLayer?.name == "Renamed during pixel move")
        #expect(model.pixelSelectionMoveTransaction == nil && model.undoStack.count == 2)
        let committed = try model.projectData()
        model.cancelPixelSelectionMove()
        model.updatePixelSelectionMove(by: CGSize(width: 8, height: 0))
        model.finishPixelSelectionMove()
        #expect(try model.projectData() == committed)
        model.undo()
        #expect(model.document.selectedLayer?.name == "Move source")
        model.undo()
        #expect(try model.projectData() == original)
        model.redo()
        model.redo()
        #expect(try model.projectData() == committed)
    }

    @Test(arguments: [false, true])
    func historyCommandFirstCancelsPixelPreviewWithoutConsumingHistory(redo: Bool) throws {
        let model = try fixture()
        model.selectXomoComponentTheme(.softMobile)
        let pending = try model.projectData()
        model.undo()
        let original = try model.projectData()
        try preview(model, changed: true)
        #expect(model.canUndo && model.canRedo)
        if redo { model.redo() } else { model.undo() }
        #expect(model.pixelSelectionMoveTransaction == nil)
        #expect(try model.projectData() == original)
        #expect(model.undoStack.isEmpty && model.redoStack.count == 1)
        model.updatePixelSelectionMove(by: CGSize(width: 8, height: 0))
        model.finishPixelSelectionMove()
        #expect(try model.projectData() == original)
        model.redo()
        #expect(try model.projectData() == pending)
        model.undo()
        #expect(try model.projectData() == original)
    }

    @Test(arguments: [false, true])
    func historyAvailabilityIncludesPixelPreviewWithEmptyStacks(redo: Bool) throws {
        let model = try fixture()
        let original = try model.projectData()
        try preview(model, changed: true)
        #expect(model.canUndo && model.canRedo)
        if redo { model.redo() } else { model.undo() }
        #expect(model.pixelSelectionMoveTransaction == nil)
        #expect(try model.projectData() == original)
        #expect(model.undoStack.isEmpty && model.redoStack.isEmpty)
        #expect(!model.canUndo && !model.canRedo)
    }

    @Test(arguments: [false, true])
    func transformBeginsAfterPixelMoveHasCommitted(rotation: Bool) throws {
        let model = try fixture()
        let original = try model.projectData()
        try preview(model, changed: true)
        let frame = try #require(model.selectedLayerTransformFrame)
        if rotation { model.beginRotatingSelectedLayer(from: CGPoint(x: frame.midX, y: frame.minY - 24)) }
        else { model.beginResizingSelectedLayer(handle: .right) }
        #expect(model.pixelSelectionMoveTransaction == nil)
        #expect(model.hasActiveSelectedLayerTransformTransaction && model.undoStack.count == 2)
        let beforeResidualEvents = try model.projectData()
        model.updatePixelSelectionMove(by: CGSize(width: 8, height: 0))
        model.cancelPixelSelectionMove()
        #expect(try model.projectData() == beforeResidualEvents)
        #expect(model.cancelTransformingSelectedLayer())
        #expect(model.undoStack.count == 1)
        model.undo()
        #expect(try model.projectData() == original)
    }

    @Test(arguments: [false, true])
    func historyClearAndProjectReloadDiscardStalePixelMoveOwnership(reload: Bool) throws {
        let model = try fixture()
        model.selectXomoComponentTheme(.softMobile)
        model.undo()
        try preview(model, changed: true)
        let displayed = try model.projectData()
        if reload {
            let replacement = try fixture()
            replacement.renameSelectedLayer(to: "Replacement project layer")
            try model.loadProjectData(replacement.projectData())
        } else {
            model.clearUndoHistory()
        }
        let expected = try model.projectData()
        #expect((expected != displayed) == reload)
        #expect(model.pixelSelectionMoveTransaction == nil)
        #expect(model.undoStack.isEmpty && model.redoStack.isEmpty)
        model.updatePixelSelectionMove(by: CGSize(width: 8, height: 0))
        #expect(!model.cancelPixelSelectionMove())
        model.finishPixelSelectionMove()
        #expect(try model.projectData() == expected)
        #expect(model.undoStack.isEmpty && model.redoStack.isEmpty)
    }

    private func fixture() throws -> ImageEditorViewModel {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        model.document.isGuideSnappingEnabled = false
        model.foregroundColor = .green
        model.clearUndoHistory()
        return model
    }

    private func preview(_ model: ImageEditorViewModel, changed: Bool) throws {
        try #require(model.beginPixelSelectionMove())
        if changed { model.updatePixelSelectionMove(by: CGSize(width: 3, height: -2)) }
    }

    private func apply(_ edit: Edit, to model: ImageEditorViewModel) {
        switch edit {
        case .rename: model.renameSelectedLayer(to: "Renamed during pixel move")
        case .theme: model.selectXomoComponentTheme(.softMobile)
        case .fill: model.fillSelection()
        case .clear: model.clearSelectionPixels()
        case .component: model.insertXomoComponent(.button, at: CGPoint(x: 8, y: 8))
        }
    }
}
