import AppKit
import Combine
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorPixelMovePreviewReuseTests {
    @Test func repeatedRoundedDeltaReusesImageAndDoesNotPublishAnotherDocument() throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        model.nudgePixelSelection(by: CGSize(width: 1, height: 0))
        model.undo()
        let original = try model.projectData()
        let redoCount = model.redoStack.count
        let undoCount = model.undoStack.count
        #expect(redoCount > 0)
        #expect(model.beginPixelSelectionMove())
        model.updatePixelSelectionMove(by: CGSize(width: 1.1, height: 0))
        let preview = try #require(model.document.selectedLayer?.image)
        let displayed = model.currentImage
        let previewPixels = try #require(imageEditorRGBABytes(preview, width: 64, height: 64))
        var publications = 0
        let observation = model.$document.dropFirst().sink { _ in publications += 1 }
        model.updatePixelSelectionMove(by: CGSize(width: 1.4, height: 0.1))
        #expect(model.document.selectedLayer?.image === preview)
        #expect(model.currentImage === displayed)
        #expect(publications == 0)
        #expect(imageEditorRGBABytes(try #require(model.document.selectedLayer?.image), width: 64, height: 64) == previewPixels)
        #expect(model.undoStack.count == undoCount)
        #expect(model.redoStack.count == redoCount)
        model.updatePixelSelectionMove(by: .zero)
        model.finishPixelSelectionMove()
        #expect(try model.projectData() == original)
        #expect(model.redoStack.count == redoCount)
        withExtendedLifetime(observation) {}
    }

    @Test func aPreviewPublishesPixelsAndSelectionAsOneCoherentDocument() throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        let originalImage = try #require(model.document.selectedLayer?.image)
        let originalSelection = model.document.selection
        var states: [(NSImage?, ImageEditorSelection?)] = []
        let observation = model.$document.dropFirst().sink { value in states.append((value.selectedLayer?.image, value.selection)) }
        #expect(model.beginPixelSelectionMove())
        model.updatePixelSelectionMove(by: CGSize(width: 2, height: 0))
        #expect(states.count == 1)
        #expect(states.allSatisfy { $0.0 !== originalImage && $0.1 != originalSelection })
        model.cancelPixelSelectionMove()
        withExtendedLifetime(observation) {}
    }

    @Test func featherChangeAtSameDeltaMustRenderFromOriginalAgain() throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        let original = try model.projectData()
        #expect(model.beginPixelSelectionMove())
        model.updatePixelSelectionMove(by: CGSize(width: 2, height: 0))
        let hardPreview = try #require(model.document.selectedLayer?.image)
        model.feather = 2
        model.updatePixelSelectionMove(by: CGSize(width: 2, height: 0))
        let softPreview = try #require(model.document.selectedLayer?.image)
        #expect(softPreview !== hardPreview)
        let fresh = try ImageEditorPixelMoveWorkflowFixture.model()
        try fresh.loadProjectData(original)
        fresh.feather = 2
        #expect(fresh.beginPixelSelectionMove())
        fresh.updatePixelSelectionMove(by: CGSize(width: 2, height: 0))
        #expect(imageEditorRGBABytes(softPreview, width: 64, height: 64)
            == imageEditorRGBABytes(try #require(fresh.document.selectedLayer?.image), width: 64, height: 64))
        model.cancelPixelSelectionMove()
        #expect(try model.projectData() == original)
    }

    @Test func shiftConstraintChangeMustNotReuseAFormerDiagonalPreview() throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        #expect(model.beginPixelSelectionMove())
        model.updatePixelSelectionMove(by: CGSize(width: 3, height: 2))
        let diagonal = try #require(model.document.selectedLayer?.image)
        model.updatePixelSelectionMove(by: CGSize(width: 3, height: 2), modifierFlags: .shift)
        #expect(model.document.selectedLayer?.image !== diagonal)
        #expect(model.document.selection?.bounds == CGRect(x: 27, y: 24, width: 16, height: 16))
        #expect(model.pixelSelectionMoveTransaction?.delta == CGSize(width: 3, height: 0))
        model.finishPixelSelectionMove()
        #expect(model.undoStack.count == 1)
    }

    @Test func interveningPixelAndSelectionReplacementInvalidatesReusablePreview() throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        #expect(model.beginPixelSelectionMove())
        model.updatePixelSelectionMove(by: CGSize(width: 2, height: 0))
        let correct = try #require(model.document.selectedLayer?.image)
        let correctPixels = try #require(imageEditorRGBABytes(correct, width: 64, height: 64))
        let selection = model.document.selection
        model.document.layers[0].image = .transparent(size: CGSize(width: 64, height: 64))
        model.updatePixelSelectionMove(by: CGSize(width: 2, height: 0))
        #expect(imageEditorRGBABytes(try #require(model.document.selectedLayer?.image), width: 64, height: 64) == correctPixels)
        model.document.selection = .rectangle(CGRect(x: 0, y: 0, width: 1, height: 1))
        model.updatePixelSelectionMove(by: CGSize(width: 2, height: 0))
        #expect(model.document.selection == selection)
        model.cancelPixelSelectionMove()
    }

    @Test func returningToZeroRestoresExpandedBackingAndPreservesExistingRedo() throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        model.nudgePixelSelection(by: CGSize(width: 1, height: 0))
        model.undo()
        let original = try model.projectData()
        let sourceImage = try #require(model.document.selectedLayer?.image)
        let redoCount = model.redoStack.count
        let undoCount = model.undoStack.count
        #expect(model.beginPixelSelectionMove())
        model.updatePixelSelectionMove(by: CGSize(width: 48, height: 0))
        #expect(try #require(model.document.selectedLayer?.frame).width > 64)
        var publications = 0
        let observation = model.$document.dropFirst().sink { _ in publications += 1 }
        model.updatePixelSelectionMove(by: .zero)
        #expect(publications == 1)
        #expect(model.document.selectedLayer?.image === sourceImage)
        #expect(model.document.selectedLayer?.frame == CGRect(x: 0, y: 0, width: 64, height: 64))
        model.finishPixelSelectionMove()
        #expect(try model.projectData() == original)
        #expect(model.redoStack.count == redoCount)
        #expect(model.undoStack.count == undoCount)
        withExtendedLifetime(observation) {}
    }
}
