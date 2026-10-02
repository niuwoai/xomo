import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorPixelSelectionLayerBoundsTests {
    private let canvasSize = NSSize(width: 16, height: 12)
    private let sourceFrame = CGRect(x: 4, y: 4, width: 4, height: 4)

    @Test(arguments: [CGSize(width: 4, height: 0), CGSize(width: -4, height: 0),
                      CGSize(width: 0, height: 4), CGSize(width: 0, height: -4)])
    func movingBeyondSmallLayerBoundsPreservesPixelsAndUndoRedo(delta: CGSize) throws {
        let model = try fixture()
        let originalImage = try #require(model.document.selectedLayer?.image)
        let before = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 16, height: 12))
        #expect(before.contains { $0 != 0 })
        let originalUndoCount = model.undoStack.count

        #expect(model.beginPixelSelectionMove(at: CGPoint(x: 6, y: 6)))
        model.updatePixelSelectionMove(by: delta)
        #expect(model.undoStack.count == originalUndoCount)
        model.finishPixelSelectionMove()

        let after = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 16, height: 12))
        #expect(after == translatedPixels(before, by: delta))
        let expanded = try #require(model.document.selectedLayer)
        #expect(expanded.frame.contains(sourceFrame.offsetBy(dx: delta.width, dy: delta.height)))
        #expect(expanded.frame.width / expanded.image.size.width == 1)
        #expect(expanded.frame.height / expanded.image.size.height == 1)
        #expect(model.undoStack.count == originalUndoCount + 1)
        model.undo()
        #expect(model.document.selectedLayer?.frame == sourceFrame)
        let undoneImage = try #require(model.document.selectedLayer?.image)
        #expect(imageEditorMaximumPixelDifference(undoneImage, originalImage) == 0)
        model.redo()
        #expect(imageEditorRGBABytes(model.document.compositedImage, width: 16, height: 12) == after)
    }

    @Test func expandedPreviewCanReturnToZeroOrCancelWithoutChangingHistory() throws {
        let model = try fixture()
        let originalPixels = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 16, height: 12))
        let originalUndoCount = model.undoStack.count
        let originalHistoryCount = model.document.history.count
        #expect(model.beginPixelSelectionMove(at: CGPoint(x: 6, y: 6)))
        model.updatePixelSelectionMove(by: CGSize(width: 4, height: 0))
        model.updatePixelSelectionMove(by: .zero)
        model.finishPixelSelectionMove()
        #expect(model.document.selectedLayer?.frame == sourceFrame)
        #expect(model.undoStack.count == originalUndoCount)
        #expect(model.document.history.count == originalHistoryCount)
        #expect(model.beginPixelSelectionMove(at: CGPoint(x: 6, y: 6)))
        model.updatePixelSelectionMove(by: CGSize(width: -4, height: 0))
        model.cancelPixelSelectionMove()
        #expect(model.document.selectedLayer?.frame == sourceFrame)
        #expect(imageEditorRGBABytes(model.document.compositedImage, width: 16, height: 12) == originalPixels)
        #expect(model.undoStack.count == originalUndoCount)
    }

    @Test func scaledLayerExpansionPreservesPixelDensityAndProjectRoundTrip() throws {
        let model = try fixture()
        let scaledFrame = CGRect(x: 4, y: 4, width: 8, height: 4)
        model.document.layers[0].frame = scaledFrame
        model.document.selection = .rectangle(scaledFrame)
        let originalImage = try #require(model.document.selectedLayer?.image)
        let originalSource = try #require(imageEditorRGBABytes(originalImage, width: 4, height: 4))
        // Move native pixels first, then render. Translating an already scaled
        // composite is a different operation at a new transparent boundary.
        let referenceImage = try #require(NSImage.rendered(size: NSSize(width: 6, height: 4)) { _ in
            originalImage.draw(in: CGRect(x: 2, y: 0, width: 4, height: 4),
                               from: .zero, operation: .copy, fraction: 1)
        })
        var referenceDocument = model.document
        referenceDocument.layers[0].image = referenceImage
        referenceDocument.layers[0].frame = CGRect(x: 4, y: 4, width: 12, height: 4)
        let expected = try #require(imageEditorRGBABytes(referenceDocument.compositedImage, width: 16, height: 12))
        #expect(model.beginPixelSelectionMove(at: CGPoint(x: 6, y: 6)))
        model.updatePixelSelectionMove(by: CGSize(width: 4, height: 0))
        model.finishPixelSelectionMove()
        let layer = try #require(model.document.selectedLayer)
        #expect(layer.frame.width / layer.image.size.width == 2)
        #expect(layer.frame.height / layer.image.size.height == 1)
        let movedSource = try #require(imageEditorRGBABytes(layer.image, width: 6, height: 4))
        for y in 0..<4 {
            #expect(Array(movedSource[(y * 6 * 4)..<((y * 6 + 2) * 4)]) == [UInt8](repeating: 0, count: 8))
            #expect(Array(movedSource[((y * 6 + 2) * 4)..<((y + 1) * 6 * 4)])
                == Array(originalSource[(y * 4 * 4)..<((y + 1) * 4 * 4)]))
        }
        let after = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 16, height: 12))
        #expect(after == expected)
        let saved = try model.projectData()
        let reopened = try fixture()
        try reopened.loadProjectData(saved)
        #expect(reopened.document.selectedLayer?.frame == layer.frame)
        #expect(imageEditorRGBABytes(reopened.document.compositedImage, width: 16, height: 12) == after)
    }

    @Test func expandingForPartialSelectionKeepsUnselectedPixelsInPlace() throws {
        let model = try fixture()
        model.document.selection = .rectangle(CGRect(x: 4, y: 4, width: 2, height: 4))
        let before = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 16, height: 12))
        var expected = before
        for y in 4..<8 {
            for x in 4..<6 {
                let from = (y * 16 + x) * 4
                let to = (y * 16 + x + 4) * 4
                expected.replaceSubrange(from..<(from + 4), with: [0, 0, 0, 0])
                expected.replaceSubrange(to..<(to + 4), with: before[from..<(from + 4)])
            }
        }
        #expect(model.beginPixelSelectionMove(at: CGPoint(x: 5, y: 6)))
        model.updatePixelSelectionMove(by: CGSize(width: 4, height: 0))
        model.finishPixelSelectionMove()
        #expect(imageEditorRGBABytes(model.document.compositedImage, width: 16, height: 12) == expected)
    }

    @Test func featheredMovePreservesCoverageBeyondSelectionBounds() throws {
        let model = try fixture()
        model.document.selection = .rectangle(CGRect(x: 4, y: 4, width: 2, height: 4))
        model.feather = 1
        #expect(model.beginPixelSelectionMove(at: CGPoint(x: 5, y: 6)))
        model.updatePixelSelectionMove(by: CGSize(width: 8, height: 0))
        model.finishPixelSelectionMove()
        let layer = try #require(model.document.selectedLayer)
        let pixels = try #require(imageEditorRGBABytes(layer.image, width: 12, height: 4))
        let alpha = stride(from: 3, to: pixels.count, by: 4).map { Int(pixels[$0]) }
        #expect(alpha.reduce(0, +) == 4 * 4 * 255)
        #expect(alpha.contains { $0 > 0 && $0 < 255 })
        for y in 0..<4 {
            for x in 0..<4 {
                #expect(alpha[y * 12 + x] + alpha[y * 12 + x + 8] == 255)
            }
        }
        #expect(alpha[2 * 12 + 10] > 0)
        model.undo()
        #expect(model.document.selectedLayer?.frame == sourceFrame)
    }

    @Test(arguments: [true, false])
    func expansionKeepsRasterAndVectorMasksInCanvasSpace(linked: Bool) throws {
        let model = try fixture()
        let mask = try #require(NSImage.rendered(size: sourceFrame.size) { _ in
            NSColor.white.setFill()
            CGRect(x: 0, y: 0, width: 2, height: 4).fill()
        })
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 4, y: 0),
                      CGPoint(x: 4, y: 4), CGPoint(x: 0, y: 4)]
        model.document.layers[0].mask = mask
        model.document.layers[0].isMaskLinked = linked
        model.document.layers[0].vectorMask = ImageEditorShapeContent(
            kind: .path, fillColor: .white, fillOpacity: 1,
            strokeColor: .white, strokeWidth: 1, strokeOpacity: 0,
            pathPoints: points, pathAnchors: points.map { ImageEditorPathAnchor(point: $0) }, isPathClosed: true
        )
        #expect(model.beginPixelSelectionMove(at: CGPoint(x: 6, y: 6)))
        model.updatePixelSelectionMove(by: CGSize(width: -4, height: 0))
        model.finishPixelSelectionMove()
        let layer = try #require(model.document.selectedLayer)
        #expect(layer.isMaskLinked == linked)
        let movedMask = try #require(layer.mask)
        let originalSample = try #require(mask.color(at: CGPoint(x: 0.5, y: 1.5)))
        let mappedSample = try #require(movedMask.color(at: CGPoint(x: 4.5, y: 1.5)))
        #expect(abs(mappedSample.alphaComponent - originalSample.alphaComponent) < 0.01)
        #expect(movedMask.color(at: CGPoint(x: 0.5, y: 1.5))?.alphaComponent == 0)
        let vector = try #require(layer.vectorMask)
        #expect(vector.pathPoints.map { CGPoint(x: layer.frame.minX + $0.x, y: layer.frame.minY + $0.y) }
            == points.map { CGPoint(x: sourceFrame.minX + $0.x, y: sourceFrame.minY + $0.y) })
    }

    @Test func oversizedExpansionIsRejectedWithoutCommittingChanges() throws {
        let model = try fixture()
        let before = try model.projectData()
        let originalUndoCount = model.undoStack.count
        #expect(model.beginPixelSelectionMove(at: CGPoint(x: 6, y: 6)))
        model.updatePixelSelectionMove(by: CGSize(width: 1_000_000_000, height: 0))
        model.finishPixelSelectionMove()
        #expect(try model.projectData() == before)
        #expect(model.undoStack.count == originalUndoCount)
    }

    private func fixture() throws -> ImageEditorViewModel {
        let image = try #require(NSImage.rendered(size: sourceFrame.size) { rect in
            NSColor.red.setFill()
            rect.fill()
            NSColor.green.setFill()
            CGRect(x: 0, y: 0, width: 2, height: 4).fill()
        })
        var layer = ImageEditorLayer.blank(name: "Pixels", size: image.size)
        layer.image = image
        layer.frame = sourceFrame
        let model = ImageEditorViewModel(sourceName: "small-layer.png", image: .transparent(size: canvasSize)) { _ in }
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        model.selectedTool = .move
        model.document.selection = .rectangle(sourceFrame)
        return model
    }

    private func translatedPixels(_ source: [UInt8], by delta: CGSize) -> [UInt8] {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        let componentsPerPixel = 4
        var output = [UInt8](repeating: 0, count: source.count)
        for y in 0..<height {
            for x in 0..<width {
                let targetX = x + Int(delta.width)
                let targetY = y + Int(delta.height)
                guard (0..<width).contains(targetX), (0..<height).contains(targetY) else { continue }
                let from = (y * width + x) * componentsPerPixel
                let to = (targetY * width + targetX) * componentsPerPixel
                output.replaceSubrange(to..<(to + componentsPerPixel), with: source[from..<(from + componentsPerPixel)])
            }
        }
        return output
    }
}
