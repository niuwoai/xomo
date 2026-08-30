import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorInspectorResizeTests {
    @Test(arguments: [false, true], [false, true])
    func subpixelSizeEditHasOneUndoStep(height: Bool, proportional: Bool) throws {
        let model = fixture()
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        model.setSelectedLayerTransform(
            width: height ? nil : 100.05,
            height: height ? 100.05 : nil,
            preservingAspectRatio: proportional
        )
        let frame = try #require(model.document.selectedLayer?.frame)
        #expect(abs((height ? frame.height : frame.width) - 100.05) < 0.000001)
        #expect(abs((height ? frame.width : frame.height) - (proportional ? 100.05 : 100)) < 0.000001)
        #expect(model.undoStack.count == undoCount + 1)
        #expect(model.document.history.last?.title == L10n.text("imageEditor.history.layerTransformInspector"))
        let after = try model.projectData()
        model.undo()
        #expect(try model.projectData() == before)
        model.redo()
        #expect(try model.projectData() == after)
    }

    @Test(arguments: [false, true], [CGSize(width: 100, height: 100), CGSize(width: 100.05, height: 91.11), CGSize(width: 1.02, height: 1.97)])
    func unchangedSizePreservesRedoHistory(proportional: Bool, size: CGSize) throws {
        let model = fixture()
        model.document.layers[0].frame.size = size
        model.setSelectedLayerTransform(width: 150)
        let resized = try model.projectData()
        model.undo()
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        let redoCount = model.redoStack.count
        #expect(redoCount > 0)
        model.setSelectedLayerTransform(width: Double(size.width), preservingAspectRatio: proportional)
        #expect(try model.projectData() == before)
        #expect(model.undoStack.count == undoCount)
        #expect(model.redoStack.count == redoCount)
        model.redo()
        #expect(try model.projectData() == resized)
    }

    @Test func combinedSubpixelPositionAndSizeIsOneTransaction() throws {
        let model = fixture()
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        model.setSelectedLayerTransform(x: 40.03, y: 40.04, width: 100.05, height: 100.06)
        let frame = try #require(model.document.selectedLayer?.frame)
        #expect(abs(frame.minX - 40.03) < 0.000001)
        #expect(abs(frame.minY - 40.04) < 0.000001)
        #expect(abs(frame.width - 100.05) < 0.000001)
        #expect(abs(frame.height - 100.06) < 0.000001)
        #expect(model.undoStack.count == undoCount + 1)
        model.undo()
        #expect(try model.projectData() == before)
    }

    @Test func subpixelResizeHelperReportsItsMutation() throws {
        let model = fixture()
        let layer = try #require(model.document.selectedLayer)
        let target = CGRect(x: 40, y: 40, width: 100.05, height: 100)
        #expect(model.applyResizedTransformFrame(
            target, originalTransformFrame: layer.frame, originalFrames: [layer.id: layer.frame]
        ))
        #expect(model.document.selectedLayer?.frame == target)
        #expect(!model.applyResizedTransformFrame(
            target, originalTransformFrame: layer.frame, originalFrames: [layer.id: layer.frame]
        ))
    }

    @Test(arguments: ["minimum", "scale", "fit", "fill"])
    func equivalentResizeCommandsPreserveRedo(command: String) throws {
        let model = fixture()
        if command == "minimum" {
            model.document.layers[0].frame.size = CGSize(width: 1, height: 1)
        } else if command == "fit" || command == "fill" {
            model.document.layers[0].frame = CGRect(origin: .zero, size: model.document.canvasSize)
        }
        model.setSelectedLayerTransform(x: 20)
        let moved = try model.projectData()
        model.undo()
        let before = try model.projectData()
        let redoCount = model.redoStack.count
        switch command {
        case "minimum": model.setSelectedLayerTransform(width: -10, height: 0)
        case "scale": model.scaleSelectedLayer(by: 1)
        case "fit": #expect(!model.fitSelectedLayerToCanvas())
        default: #expect(!model.fillSelectedLayerToCanvas())
        }
        #expect(try model.projectData() == before)
        #expect(model.redoStack.count == redoCount)
        model.redo()
        #expect(try model.projectData() == moved)
    }

    @Test func overflowingProportionalSizePreservesDocumentAndHistory() throws {
        let model = fixture()
        model.document.layers[0].frame.size = CGSize(width: 1, height: 100)
        model.setSelectedLayerTransform(x: 60)
        model.undo()
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        let redoCount = model.redoStack.count
        model.setSelectedLayerTransform(width: Double.greatestFiniteMagnitude, preservingAspectRatio: true)
        #expect(try model.projectData() == before)
        #expect(model.undoStack.count == undoCount)
        #expect(model.redoStack.count == redoCount)
    }

    @Test func pointerSubpixelResizeCommitsUndo() throws {
        let model = fixture()
        model.document.isGuideSnappingEnabled = false
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        model.beginResizingSelectedLayer(handle: .right)
        model.resizeSelectedLayer(to: CGPoint(x: 140.05, y: 90), handle: .right)
        model.finishResizingSelectedLayer()
        #expect(abs((model.document.selectedLayer?.frame.width ?? 0) - 100.05) < 0.000001)
        #expect(model.undoStack.count == undoCount + 1)
        #expect(model.document.history.last?.title == L10n.text("imageEditor.history.layerResize"))
        model.undo()
        #expect(try model.projectData() == before)
    }

    @Test func multiLayerSubpixelResizeCommitsAllFramesTogether() throws {
        let model = fixture()
        var second = ImageEditorLayer.blank(name: "Second", size: CGSize(width: 100, height: 100))
        second.image = model.document.layers[0].image
        second.frame = CGRect(x: 160, y: 40, width: 100, height: 100)
        model.document.layers.append(second)
        model.selectLayer(second.id, extendingSelection: true)
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        model.setSelectedLayerTransform(width: 220.05)
        #expect(abs((model.selectedLayerTransformFrame?.width ?? 0) - 220.05) < 0.000001)
        #expect(model.document.layers.allSatisfy { $0.frame.width > 100 })
        #expect(model.undoStack.count == undoCount + 1)
        model.undo()
        #expect(try model.projectData() == before)
    }

    private func fixture() -> ImageEditorViewModel {
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: CGSize(width: 300, height: 300))) { _ in }
        var layer = ImageEditorLayer.blank(name: "Content", size: CGSize(width: 100, height: 100))
        layer.image = NSImage.rendered(size: layer.image.size) { rect in
            NSColor.red.setFill()
            rect.fill()
        } ?? layer.image
        layer.frame = CGRect(x: 40, y: 40, width: 100, height: 100)
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        #expect(model.canResizeSelectedLayer)
        return model
    }
}
