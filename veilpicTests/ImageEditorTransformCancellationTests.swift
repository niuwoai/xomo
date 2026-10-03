import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorTransformCancellationTests {
    enum Completion: CaseIterable { case escape, unchanged, undo, redo }

    @Test(arguments: [false, true], Completion.allCases)
    func abortedTransformPreservesPendingDocumentAndThemeRedo(rotation: Bool, completion: Completion) throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        let pendingTheme: XomoComponentTheme = model.xomoComponentTheme == .native ? .softMobile : .native
        model.selectXomoComponentTheme(pendingTheme)
        let pendingRedo = try model.projectData()
        model.undo()
        let original = try model.projectData()
        let originalTheme = model.xomoComponentTheme
        let originalHistory = model.document.history
        let originalUndoCount = model.undoStack.count
        #expect(model.redoStack.count == 1)
        let frame = try #require(model.selectedLayerTransformFrame)
        let start = CGPoint(x: frame.midX, y: frame.minY - 24)
        let end = CGPoint(x: frame.maxX + 24, y: frame.midY)
        if rotation { model.beginRotatingSelectedLayer(from: start) }
        else { model.beginResizingSelectedLayer(handle: .right) }
        #expect(model.hasActiveSelectedLayerTransformTransaction)
        #expect(model.canUndo && model.canRedo)
        if completion != .unchanged {
            if rotation { model.rotateSelectedLayer(to: end) }
            else { model.resizeSelectedLayer(to: end, handle: .right) }
        }
        switch completion {
        case .escape: #expect(model.cancelTransformingSelectedLayer())
        case .unchanged:
            if rotation { model.finishRotatingSelectedLayer() }
            else { model.finishResizingSelectedLayer() }
        case .undo: model.undo()
        case .redo: model.redo()
        }
        // Releasing or receiving stale preview events after cancellation is inert.
        model.rotateSelectedLayer(to: CGPoint(x: frame.midX, y: frame.maxY + 24))
        model.resizeSelectedLayer(to: CGPoint(x: frame.maxX + 48, y: frame.midY), handle: .right)
        model.finishRotatingSelectedLayer()
        model.finishResizingSelectedLayer()
        #expect(!model.hasActiveSelectedLayerTransformTransaction)
        #expect(model.rotatingLayerIDs.isEmpty && model.resizingLayerIDs.isEmpty)
        #expect(try model.projectData() == original)
        #expect(model.xomoComponentTheme == originalTheme)
        #expect(model.document.history == originalHistory)
        #expect(model.undoStack.count == originalUndoCount)
        #expect(model.redoStack.count == 1)
        model.redo()
        #expect(model.xomoComponentTheme == pendingTheme)
        #expect(try model.projectData() == pendingRedo)
    }

    @Test(arguments: [false, true])
    func committedTransformReplacesOldRedoWithExactlyOneUndo(rotation: Bool) throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        let originalTheme = model.xomoComponentTheme
        model.selectXomoComponentTheme(originalTheme == .native ? .softMobile : .native)
        model.undo()
        let original = try model.projectData()
        let undoCount = model.undoStack.count
        let historyCount = model.document.history.count
        let frame = try #require(model.selectedLayerTransformFrame)
        let end = CGPoint(x: frame.maxX + 24, y: frame.midY)
        if rotation {
            model.beginRotatingSelectedLayer(from: CGPoint(x: frame.midX, y: frame.minY - 24))
            model.rotateSelectedLayer(to: end)
            model.finishRotatingSelectedLayer()
        } else {
            model.beginResizingSelectedLayer(handle: .right)
            model.resizeSelectedLayer(to: end, handle: .right)
            model.finishResizingSelectedLayer()
        }
        let committed = try model.projectData()
        #expect(committed != original)
        #expect(model.undoStack.count == undoCount + 1 && model.redoStack.isEmpty)
        #expect(model.document.history.count == historyCount + 1)
        #expect(!model.hasActiveSelectedLayerTransformTransaction && !model.canRedo)
        model.undo()
        #expect(try model.projectData() == original && model.xomoComponentTheme == originalTheme)
        model.redo()
        #expect(try model.projectData() == committed && model.xomoComponentTheme == originalTheme)
    }

    @Test(arguments: [false, true])
    func historyCommandsCancelTransformEvenWithoutPendingRedo(rotation: Bool) throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        let original = try model.projectData()
        let undoCount = model.undoStack.count
        let frame = try #require(model.selectedLayerTransformFrame)
        if rotation {
            model.beginRotatingSelectedLayer(from: CGPoint(x: frame.midX, y: frame.minY - 24))
            model.rotateSelectedLayer(to: CGPoint(x: frame.maxX + 24, y: frame.midY))
        } else {
            model.beginResizingSelectedLayer(handle: .right)
            model.resizeSelectedLayer(to: CGPoint(x: frame.maxX + 24, y: frame.midY), handle: .right)
        }
        #expect(model.canUndo && model.canRedo && model.redoStack.isEmpty)
        model.redo()
        #expect(try model.projectData() == original)
        #expect(model.undoStack.count == undoCount && model.redoStack.isEmpty)
        #expect(!model.hasActiveSelectedLayerTransformTransaction && !model.canRedo)
        model.finishRotatingSelectedLayer()
        model.finishResizingSelectedLayer()
        #expect(try model.projectData() == original)
    }

    @Test(arguments: [false, true])
    func overlappingTransformCannotReplaceTheActiveSnapshot(rotation: Bool) throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        model.renameSelectedLayer(to: "Pending redo layer")
        model.undo()
        let original = try model.projectData()
        let undoCount = model.undoStack.count
        let frame = try #require(model.selectedLayerTransformFrame)
        if rotation {
            model.beginRotatingSelectedLayer(from: CGPoint(x: frame.midX, y: frame.minY - 24))
            model.beginResizingSelectedLayer(handle: .right)
            #expect(model.resizingLayerIDs.isEmpty && !model.rotatingLayerIDs.isEmpty)
        } else {
            model.beginResizingSelectedLayer(handle: .right)
            model.beginRotatingSelectedLayer(from: CGPoint(x: frame.midX, y: frame.minY - 24))
            #expect(model.rotatingLayerIDs.isEmpty && !model.resizingLayerIDs.isEmpty)
        }
        #expect(model.undoStack.count == undoCount + 1)
        #expect(model.cancelTransformingSelectedLayer())
        #expect(try model.projectData() == original)
        #expect(model.undoStack.count == undoCount && model.redoStack.count == 1)
    }

    @Test(arguments: [false, true])
    func clearedHistoryOrReplacedDocumentCannotResurrectCancelledRedo(reload: Bool) throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        model.renameSelectedLayer(to: "Pending redo layer")
        model.undo()
        let original = try model.projectData()
        let frame = try #require(model.selectedLayerTransformFrame)
        model.beginResizingSelectedLayer(handle: .right)
        model.resizeSelectedLayer(to: CGPoint(x: frame.maxX + 24, y: frame.midY), handle: .right)
        if reload { try model.loadProjectData(original) }
        else { model.clearUndoHistory() }
        let replacement = try model.projectData()
        #expect(reload ? replacement == original : replacement != original)
        #expect(model.rotatingLayerIDs.isEmpty && model.resizingLayerIDs.isEmpty)
        #expect(!model.hasActiveSelectedLayerTransformTransaction && !model.canUndo && !model.canRedo)
        model.finishResizingSelectedLayer()
        #expect(!model.cancelTransformingSelectedLayer())
        #expect(model.undoStack.isEmpty && model.redoStack.isEmpty)
        #expect(try model.projectData() == replacement)
    }

    @Test func escapeCancelsResizeWithoutChangingDocumentHistoryOrUndo() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 70))
        let originalFrames = layerFrames(in: viewModel)
        let originalImages = layerImages(in: viewModel)
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count
        let frame = try #require(viewModel.selectedLayerTransformFrame)

        viewModel.beginResizingSelectedLayer(handle: .right)
        viewModel.resizeSelectedLayer(
            to: CGPoint(x: frame.maxX + 48, y: frame.midY),
            handle: .right
        )

        #expect(layerFrames(in: viewModel) != originalFrames)
        #expect(viewModel.cancelTransformingSelectedLayer())
        #expect(layerFrames(in: viewModel) == originalFrames)
        #expect(layerImages(in: viewModel) == originalImages)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.resizingLayerIDs.isEmpty)
        #expect(viewModel.cancelTransformingSelectedLayer() == false)

        viewModel.finishResizingSelectedLayer()
        #expect(layerFrames(in: viewModel) == originalFrames)
    }

    @Test func escapeCancelsRotationWithoutChangingDocumentHistoryOrUndo() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 70))
        let originalFrames = layerFrames(in: viewModel)
        let originalImages = layerImages(in: viewModel)
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count
        let frame = try #require(viewModel.selectedLayerTransformFrame)
        let start = CGPoint(x: frame.midX, y: frame.minY - 30)
        let end = CGPoint(x: frame.maxX + 30, y: frame.midY)

        viewModel.beginRotatingSelectedLayer(from: start)
        viewModel.rotateSelectedLayer(to: end)

        #expect(layerFrames(in: viewModel) != originalFrames)
        #expect(viewModel.rotatingPreviewDegrees != nil)
        #expect(viewModel.cancelTransformingSelectedLayer())
        #expect(layerFrames(in: viewModel) == originalFrames)
        #expect(layerImages(in: viewModel) == originalImages)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.rotatingLayerIDs.isEmpty)
        #expect(viewModel.rotatingPreviewDegrees == nil)
        #expect(viewModel.cancelTransformingSelectedLayer() == false)

        viewModel.finishRotatingSelectedLayer()
        #expect(layerFrames(in: viewModel) == originalFrames)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        let image = NSImage(size: NSSize(width: 360, height: 240))
        image.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.unlockFocus()
        return ImageEditorViewModel(sourceName: "transform-cancel", image: image) { _ in }
    }

    private func layerFrames(in viewModel: ImageEditorViewModel) -> [UUID: CGRect] {
        Dictionary(uniqueKeysWithValues: viewModel.document.layers.map { ($0.id, $0.frame.standardized) })
    }

    private func layerImages(in viewModel: ImageEditorViewModel) -> [UUID: Data] {
        Dictionary(uniqueKeysWithValues: viewModel.document.layers.compactMap { layer in
            layer.image.tiffRepresentation.map { (layer.id, $0) }
        })
    }
}
