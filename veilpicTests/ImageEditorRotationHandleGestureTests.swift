import AppKit
import SwiftUI
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorRotationHandleGestureTests {
    @Test(arguments: [CGRect(x: 0, y: 0, width: 64, height: 64),
                      CGRect(x: 200, y: 140, width: 192, height: 192)])
    func canvasPixelDragCannotAcquireRotationOrAddHistory(rect: CGRect) throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        let original = try model.projectData()
        let historyCount = model.document.history.count
        let undoCount = model.undoStack.count
        var rotating = false
        var callbacks = 0
        let handle = ImageEditorLayerRotationHandle(rect: rect, isRotating: Binding(get: { rotating }, set: { rotating = $0 }),
            canBegin: { true }, onBegan: { _ in callbacks += 1 },
            onChanged: { _ in callbacks += 1 }, onEnded: { callbacks += 1 })
        let start = CGPoint(x: rect.midX - rect.width / 16, y: rect.midY - rect.height / 16)
        let end = CGPoint(x: start.x + rect.width / 4, y: start.y + rect.height / 8)
        #expect(model.beginPixelSelectionMove())
        handle.dragChanged(startLocation: start, location: end)
        model.updatePixelSelectionMove(by: CGSize(width: 16, height: 8))
        handle.dragChanged(startLocation: start, location: end)
        model.finishPixelSelectionMove()
        handle.dragEnded()
        #expect(callbacks == 0 && !rotating)
        #expect(model.rotatingLayerIDs.isEmpty)
        #expect(model.document.history.count == historyCount + 1)
        #expect(model.document.history.last?.title == L10n.text("imageEditor.history.selectionPixelsMove"))
        #expect(model.undoStack.count == undoCount + 1)
        let moved = try model.projectData()
        #expect(moved != original)
        model.undo()
        #expect(try model.projectData() == original)
        model.redo()
        #expect(try model.projectData() == moved)
    }

    @Test func handleDragUsesNamedCanvasCoordinatesAndFinishesSingleRotation() throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        let original = try model.projectData()
        let historyCount = model.document.history.count
        let undoCount = model.undoStack.count
        let rect = CGRect(x: 200, y: 140, width: 192, height: 192)
        func canvasPoint(_ point: CGPoint) -> CGPoint { CGPoint(x: (point.x - rect.minX) / 3, y: (point.y - rect.minY) / 3) }
        var rotating = false
        var starts: [CGPoint] = []
        var updates: [CGPoint] = []
        var finishes = 0
        let handle = ImageEditorLayerRotationHandle(rect: rect, isRotating: Binding(get: { rotating }, set: { rotating = $0 }),
            canBegin: { true }, onBegan: { point in
                starts.append(point)
                model.beginRotatingSelectedLayer(from: canvasPoint(point))
            }, onChanged: { point in
                updates.append(point)
                model.rotateSelectedLayer(to: canvasPoint(point))
            }, onEnded: {
                #expect(!rotating)
                finishes += 1
                model.finishRotatingSelectedLayer()
            })
        let start = handle.handlePoint
        let end = CGPoint(x: rect.maxX + 24, y: rect.midY)
        handle.dragChanged(startLocation: start, location: start)
        handle.dragChanged(startLocation: start, location: end)
        #expect(rotating)
        #expect(model.rotatingPreviewDegrees == 90)
        handle.dragEnded()
        handle.dragEnded()
        #expect(starts == [start] && updates == [start, end])
        #expect(finishes == 1 && !rotating)
        #expect(model.document.history.count == historyCount + 1)
        #expect(model.document.history.last?.title == L10n.text("imageEditor.history.layerRotate"))
        #expect(model.undoStack.count == undoCount + 1)
        let rotated = try model.projectData()
        model.undo()
        #expect(try model.projectData() == original)
        model.redo()
        #expect(try model.projectData() == rotated)
    }

    @Test(arguments: [true, false])
    func deniedPanOrLockDoesNotAcquireHandle(allowed: Bool) {
        var rotating = false
        var starts = 0
        var updates = 0
        var ends = 0
        let handle = ImageEditorLayerRotationHandle(rect: CGRect(x: 100, y: 100, width: 100, height: 80),
            isRotating: Binding(get: { rotating }, set: { rotating = $0 }), canBegin: { allowed },
            onBegan: { _ in starts += 1 }, onChanged: { _ in updates += 1 }, onEnded: { ends += 1 })
        handle.dragChanged(startLocation: handle.handlePoint, location: handle.handlePoint)
        handle.dragEnded()
        #expect(starts == (allowed ? 1 : 0))
        #expect(updates == (allowed ? 1 : 0))
        #expect(ends == (allowed ? 1 : 0))
        #expect(!rotating)
    }

    @Test func cancelledHandleCannotCommitWhenReleaseArrives() throws {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        let original = try model.projectData()
        let historyCount = model.document.history.count
        let undoCount = model.undoStack.count
        var rotating = false
        var ends = 0
        let handle = ImageEditorLayerRotationHandle(rect: CGRect(x: 0, y: 0, width: 64, height: 64),
            isRotating: Binding(get: { rotating }, set: { rotating = $0 }), canBegin: { true },
            onBegan: { model.beginRotatingSelectedLayer(from: $0) },
            onChanged: { model.rotateSelectedLayer(to: $0) },
            onEnded: { ends += 1; model.finishRotatingSelectedLayer() })
        handle.dragChanged(startLocation: handle.handlePoint, location: CGPoint(x: 88, y: 32))
        #expect(model.cancelTransformingSelectedLayer())
        rotating = false
        handle.dragEnded()
        #expect(ends == 0)
        #expect(try model.projectData() == original)
        #expect(model.document.history.count == historyCount)
        #expect(model.undoStack.count == undoCount)
    }

    @Test func hitRegionIsBoundedAndRejectsNonfiniteCoordinates() {
        let center = CGPoint(x: 400, y: 76)
        #expect(ImageEditorRotationHandleHitRegion.contains(center, handlePoint: center))
        #expect(ImageEditorRotationHandleHitRegion.contains(CGPoint(x: 409, y: 76), handlePoint: center))
        for point in [CGPoint(x: 409, y: 85), CGPoint(x: 410, y: 76), CGPoint(x: 400, y: 86),
                      CGPoint(x: 400, y: 100), CGPoint(x: CGFloat.nan, y: 76),
                      CGPoint(x: 400, y: CGFloat.infinity)] {
            #expect(!ImageEditorRotationHandleHitRegion.contains(point, handlePoint: center))
        }
        #expect(!ImageEditorRotationHandleHitRegion.contains(center, handlePoint: CGPoint(x: CGFloat.infinity, y: 76)))
    }
}
