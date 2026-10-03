import AppKit
import SwiftUI
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorTransformEditBoundaryTests {
    enum Edit: CaseIterable { case rename, theme, nudge, pixelNudge, component }

    @Test(arguments: [false, true], Edit.allCases)
    func effectiveEditKeepsChangedAndUnchangedGesturesIndependent(rotation: Bool, edit: Edit) throws {
        for changed in [false, true] {
            try effectiveEditCommitsPreviewBeforeItsOwnUndo(rotation: rotation, changed: changed, edit: edit)
        }
    }

    func effectiveEditCommitsPreviewBeforeItsOwnUndo(rotation: Bool, changed: Bool, edit: Edit) throws {
        let model = try fixture()
        if edit == .pixelNudge { model.document.selection = .rectangle(CGRect(x: 24, y: 24, width: 16, height: 16)) }
        let originalTheme = model.xomoComponentTheme
        model.selectXomoComponentTheme(.softMobile)
        model.undo()
        let original = try model.projectData()
        let historyCount = model.document.history.count
        let reference = try fixture()
        reference.document = model.document
        reference.xomoComponentTheme = originalTheme
        try #require(reference.projectData() == original)
        let frame = try #require(model.selectedLayerTransformFrame)

        // An explicitly completed gesture is the independent workflow control.
        preview(reference, rotation: rotation, changed: changed, frame: frame)
        finish(reference, rotation: rotation)
        let expectedTransform = try reference.projectData()
        #expect((expectedTransform != original) == changed)
        preview(model, rotation: rotation, changed: changed, frame: frame)
        #expect(model.hasActiveSelectedLayerTransformTransaction)
        apply(edit, to: model)
        #expect(!model.hasActiveSelectedLayerTransformTransaction)
        #expect(model.rotatingLayerIDs.isEmpty && model.resizingLayerIDs.isEmpty)
        #expect(model.undoStack.count == (changed ? 2 : 1) && model.redoStack.isEmpty)
        #expect(model.document.history.count == historyCount + (changed ? 2 : 1))
        let committed = try model.projectData()
        #expect(committed != expectedTransform)

        // Old pointer samples, release, and Escape must not erase the new edit.
        model.rotateSelectedLayer(to: CGPoint(x: frame.midX, y: frame.maxY + 24))
        model.resizeSelectedLayer(to: CGPoint(x: frame.maxX + 48, y: frame.midY), handle: .right)
        model.finishRotatingSelectedLayer()
        model.finishResizingSelectedLayer()
        #expect(!model.cancelTransformingSelectedLayer())
        #expect(try model.projectData() == committed)
        model.undo()
        #expect(try model.projectData() == expectedTransform)
        #expect(model.xomoComponentTheme == originalTheme)
        if changed {
            model.undo()
            #expect(try model.projectData() == original)
            model.redo()
            #expect(try model.projectData() == expectedTransform)
        }
        model.redo()
        #expect(try model.projectData() == committed)
        #expect(model.undoStack.count == (changed ? 2 : 1) && model.redoStack.isEmpty)
    }

    @Test(arguments: [false, true])
    func rejectedAndUnchangedEditsLeaveThePointerTransactionOwned(rotation: Bool) throws {
        let model = try fixture()
        model.document.selection = .rectangle(CGRect(x: 24, y: 24, width: 16, height: 16))
        model.selectXomoComponentTheme(.softMobile)
        let pending = try model.projectData()
        model.undo()
        let original = try model.projectData()
        let frame = try #require(model.selectedLayerTransformFrame)
        preview(model, rotation: rotation, changed: true, frame: frame)
        let previewData = try model.projectData()
        model.renameSelectedLayer(to: "Move source")
        model.renameSelectedLayer(to: "   ")
        model.selectXomoComponentTheme(model.xomoComponentTheme)
        model.nudgeSelectionOrSelectedLayer(by: .zero)
        model.nudgePixelSelection(by: .zero)
        #expect(model.hasActiveSelectedLayerTransformTransaction)
        #expect(try model.projectData() == previewData && model.undoStack.count == 1)
        #expect(model.cancelTransformingSelectedLayer())
        #expect(try model.projectData() == original)
        #expect(model.undoStack.isEmpty && model.redoStack.count == 1)
        model.redo()
        #expect(try model.projectData() == pending)
    }

    @Test(arguments: [false, true])
    func automationRenameUsesTheSameTransactionBoundary(rotation: Bool) throws {
        let model = try fixture()
        let original = try model.projectData()
        let frame = try #require(model.selectedLayerTransformFrame)
        preview(model, rotation: rotation, changed: true, frame: frame)
        let registry = XomoAutomationRegistry.shared
        registry.register(model)
        defer { registry.unregister(model) }
        let response = registry.execute(XomoAutomationWireRequest(token: "test-only", operation: "call",
            name: "xomo.layer.rename", arguments: ["name": .string("Automation rename")]))
        #expect(response.ok)
        #expect(model.document.selectedLayer?.name == "Automation rename")
        #expect(!model.hasActiveSelectedLayerTransformTransaction && model.undoStack.count == 2)
        let committed = try model.projectData()
        #expect(!model.cancelTransformingSelectedLayer())
        model.undo()
        #expect(model.document.selectedLayer?.name == "Move source")
        model.undo()
        #expect(try model.projectData() == original)
        model.redo()
        model.redo()
        #expect(try model.projectData() == committed)
    }

    @Test func rotationHandleResidualEventsCannotRestartAfterAnEdit() throws {
        let model = try fixture()
        let original = try model.projectData()
        let frame = try #require(model.selectedLayerTransformFrame)
        var rotating = false
        var starts = 0
        let binding = SwiftUI.Binding(get: { rotating }, set: { rotating = $0 })
        let handle = ImageEditorLayerRotationHandle(rect: frame, isRotating: binding, canBegin: { true },
            onBegan: { point in starts += 1; model.beginRotatingSelectedLayer(from: point) },
            onChanged: { model.rotateSelectedLayer(to: $0) }, onEnded: { model.finishRotatingSelectedLayer() })
        let start = handle.handlePoint
        handle.dragChanged(startLocation: start, location: CGPoint(x: frame.maxX + 40, y: frame.minY - 40))
        #expect(rotating && starts == 1 && model.hasActiveSelectedLayerTransformTransaction)
        model.renameSelectedLayer(to: "Renamed during handle drag")
        let committed = try model.projectData()
        handle.dragChanged(startLocation: start, location: CGPoint(x: frame.maxX + 80, y: frame.midY))
        handle.dragEnded()
        #expect(!rotating && starts == 1 && !model.hasActiveSelectedLayerTransformTransaction)
        #expect(try model.projectData() == committed && model.undoStack.count == 2)
        model.undo()
        model.undo()
        #expect(try model.projectData() == original)
    }

    private func fixture() throws -> ImageEditorViewModel {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        model.document.selection = nil
        model.document.isGuideSnappingEnabled = false
        model.clearUndoHistory()
        return model
    }

    private func preview(_ model: ImageEditorViewModel, rotation: Bool, changed: Bool, frame: CGRect) {
        if rotation {
            model.beginRotatingSelectedLayer(from: CGPoint(x: frame.midX, y: frame.minY - 24))
            if changed {
                model.rotateSelectedLayer(to: CGPoint(x: frame.maxX + 40, y: frame.minY - 40))
            }
        } else {
            model.beginResizingSelectedLayer(handle: .right)
            if changed { model.resizeSelectedLayer(to: CGPoint(x: frame.maxX + 40, y: frame.midY), handle: .right) }
        }
    }

    private func finish(_ model: ImageEditorViewModel, rotation: Bool) {
        if rotation { model.finishRotatingSelectedLayer() }
        else { model.finishResizingSelectedLayer() }
    }

    private func apply(_ edit: Edit, to model: ImageEditorViewModel) {
        switch edit {
        case .rename: model.renameSelectedLayer(to: "Renamed during preview")
        case .theme: model.selectXomoComponentTheme(.softMobile)
        case .nudge: model.nudgeSelectionOrSelectedLayer(by: CGSize(width: 3, height: -2))
        case .pixelNudge: model.nudgePixelSelection(by: CGSize(width: 3, height: -2))
        case .component: model.insertXomoComponent(.button, at: CGPoint(x: 8, y: 8))
        }
    }
}
