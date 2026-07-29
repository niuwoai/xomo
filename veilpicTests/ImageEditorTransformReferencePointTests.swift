import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorTransformReferencePointTests {
    @Test func referencePointDefaultsToSelectionCenterAndCanMoveOutsideIt() throws {
        let viewModel = makeViewModel()
        let frame = try #require(viewModel.selectedLayerTransformFrame)

        #expect(viewModel.selectedLayerTransformReferencePoint == frame.center)
        #expect(!viewModel.hasCustomTransformReferencePoint)

        let customPoint = CGPoint(x: frame.minX - 18, y: frame.maxY + 12)
        viewModel.setSelectedLayerTransformReferencePoint(customPoint)

        #expect(viewModel.selectedLayerTransformReferencePoint == customPoint)
        #expect(viewModel.hasCustomTransformReferencePoint)
        #expect(viewModel.resetSelectedLayerTransformReferencePoint())
        #expect(viewModel.selectedLayerTransformReferencePoint == frame.center)
    }

    @Test func referencePointFollowsLightweightMovePreviewAndCommit() throws {
        let viewModel = makeViewModel()
        let frame = try #require(viewModel.selectedLayerTransformFrame)
        let originalPoint = CGPoint(x: frame.maxX, y: frame.maxY)
        viewModel.setSelectedLayerTransformReferencePoint(originalPoint)

        #expect(viewModel.beginMovingSelectedLayer())
        viewModel.moveSelectedLayer(by: CGSize(width: 16, height: 9))
        #expect(
            viewModel.selectedLayerTransformReferencePoint
                == CGPoint(x: originalPoint.x + 16, y: originalPoint.y + 9)
        )
        viewModel.finishMovingSelectedLayer()

        #expect(
            viewModel.selectedLayerTransformReferencePoint
                == CGPoint(x: originalPoint.x + 16, y: originalPoint.y + 9)
        )
    }

    @Test func cancellingReferencePointDragRestoresExactStartingState() throws {
        let viewModel = makeViewModel()
        let selectedLayerID = try #require(viewModel.document.selectedLayerID)
        let originalUnitPoint = CGPoint(x: -0.15, y: 1.2)
        viewModel.transformReferenceLayerIDs = [selectedLayerID]
        viewModel.transformReferenceUnitPoint = originalUnitPoint

        viewModel.beginSelectedLayerTransformReferencePointDrag()
        viewModel.transformReferenceLayerIDs = []
        viewModel.transformReferenceUnitPoint = CGPoint(x: 1.4, y: -0.3)

        #expect(viewModel.isTransformReferencePointDragActive)
        #expect(viewModel.cancelSelectedLayerTransformReferencePointDrag())
        #expect(viewModel.transformReferenceLayerIDs == Set([selectedLayerID]))
        #expect(viewModel.transformReferenceUnitPoint == originalUnitPoint)
        #expect(!viewModel.isTransformReferencePointDragActive)
        #expect(!viewModel.cancelSelectedLayerTransformReferencePointDrag())

        viewModel.clearSelectedLayerTransformReferencePoint()
        viewModel.beginSelectedLayerTransformReferencePointDrag()
        viewModel.transformReferenceLayerIDs = [selectedLayerID]
        viewModel.transformReferenceUnitPoint = CGPoint(x: 0.8, y: 0.2)
        #expect(viewModel.cancelSelectedLayerTransformReferencePointDrag())
        #expect(viewModel.transformReferenceLayerIDs.isEmpty)
        #expect(viewModel.transformReferenceUnitPoint == nil)
    }

    @Test func customReferencePointControlsInteractiveRotationAndSurvivesCommit() throws {
        let viewModel = makeViewModel(size: CGSize(width: 40, height: 20))
        let originalFrame = try #require(viewModel.document.selectedLayer?.frame.standardized)
        let pivot = CGPoint(x: originalFrame.minX, y: originalFrame.minY)
        viewModel.setSelectedLayerTransformReferencePoint(pivot)

        viewModel.beginRotatingSelectedLayer(from: CGPoint(x: pivot.x + 30, y: pivot.y))
        viewModel.rotateSelectedLayer(to: CGPoint(x: pivot.x, y: pivot.y + 30))
        viewModel.finishRotatingSelectedLayer()

        let rotatedFrame = try #require(viewModel.document.selectedLayer?.frame.standardized)
        #expect(abs(rotatedFrame.minX - (pivot.x - originalFrame.height)) < 0.01)
        #expect(abs(rotatedFrame.minY - pivot.y) < 0.01)
        #expect(abs(rotatedFrame.width - originalFrame.height) < 0.01)
        #expect(abs(rotatedFrame.height - originalFrame.width) < 0.01)
        #expect(viewModel.selectedLayerTransformReferencePoint == pivot)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerRotate"))

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.frame.standardized == originalFrame)
        #expect(!viewModel.hasCustomTransformReferencePoint)
    }

    @Test func defaultCenterRotationDoesNotCreateAHiddenCustomPivot() throws {
        let viewModel = makeViewModel(size: CGSize(width: 40, height: 20))
        let frame = try #require(viewModel.selectedLayerTransformFrame)

        viewModel.beginRotatingSelectedLayer(from: CGPoint(x: frame.midX + 30, y: frame.midY))
        viewModel.rotateSelectedLayer(to: CGPoint(x: frame.midX, y: frame.midY + 30))
        viewModel.finishRotatingSelectedLayer()

        #expect(!viewModel.hasCustomTransformReferencePoint)
        #expect(viewModel.selectedLayerTransformReferencePoint == viewModel.selectedLayerTransformFrame?.center)
    }

    @Test func rotationCommandsUseTheSameCustomReferencePoint() throws {
        let viewModel = makeViewModel(size: CGSize(width: 40, height: 20))
        let originalFrame = try #require(viewModel.document.selectedLayer?.frame.standardized)
        let pivot = CGPoint(x: originalFrame.minX, y: originalFrame.minY)
        viewModel.setSelectedLayerTransformReferencePoint(pivot)

        viewModel.rotateSelectedLayer(degrees: 90)

        let rotatedFrame = try #require(viewModel.document.selectedLayer?.frame.standardized)
        #expect(abs(rotatedFrame.minX - (pivot.x - originalFrame.height)) < 0.01)
        #expect(abs(rotatedFrame.minY - pivot.y) < 0.01)
        #expect(viewModel.selectedLayerTransformReferencePoint == pivot)
    }

    private func makeViewModel(size: CGSize = CGSize(width: 120, height: 80)) -> ImageEditorViewModel {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return ImageEditorViewModel(sourceName: "transform-reference-point", image: image) { _ in }
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
