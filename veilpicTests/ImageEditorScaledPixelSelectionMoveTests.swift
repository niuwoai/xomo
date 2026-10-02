import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorScaledPixelSelectionMoveTests {
    @Test(arguments: [2.0, 4.0], [CGSize(width: 1, height: 0), CGSize(width: -1, height: 0),
                                CGSize(width: 0, height: 1), CGSize(width: 0, height: -1)])
    func singleCanvasPixelNudgeUsesFractionalLocalPixelCoverage(scale: Double, delta: CGSize) throws {
        let model = try fixture(scale: scale)
        let originalLayer = try #require(model.document.selectedLayer)
        let originalSelection = model.document.selection
        let originalUndoCount = model.undoStack.count

        model.nudgeSelectionOrSelectedLayer(by: delta)

        let moved = try #require(model.document.selectedLayer)
        let horizontal = delta.width != 0
        let width = horizontal ? 4 : 3
        let height = horizontal ? 3 : 4
        #expect(moved.image.size == CGSize(width: width, height: height))
        #expect(moved.frame.width == CGFloat(width) * CGFloat(scale))
        #expect(moved.frame.height == CGFloat(height) * CGFloat(scale))
        #expect(model.document.selection?.bounds == originalLayer.frame.offsetBy(dx: delta.width, dy: delta.height))
        let pixels = try #require(imageEditorRGBABytes(moved.image, width: width, height: height))
        let localFraction = 1 / scale
        let leading = UInt8((255 * (delta.width + delta.height > 0 ? 1 - localFraction : localFraction)).rounded())
        let trailing = UInt8((255 * (delta.width + delta.height > 0 ? localFraction : 1 - localFraction)).rounded())
        for y in 0..<height {
            for x in 0..<width {
                let along = horizontal ? x : y
                let alpha: UInt8 = along == 0 ? leading : along == 3 ? trailing : 255
                let offset = (y * width + x) * 4
                #expect(Array(pixels[offset..<(offset + 4)]) == [alpha, 0, 0, alpha])
            }
        }
        #expect(model.undoStack.count == originalUndoCount + 1)
        model.undo()
        #expect(model.document.selection == originalSelection)
        #expect(model.document.selectedLayer?.frame == originalLayer.frame)
        let undone = try #require(model.document.selectedLayer?.image)
        #expect(imageEditorMaximumPixelDifference(undone, originalLayer.image) == 0)
        model.redo()
        let redone = try #require(model.document.selectedLayer?.image)
        #expect(imageEditorRGBABytes(redone, width: width, height: height) == pixels)
    }

    @Test func fractionalPreviewCanReturnToZeroWithoutResamplingOrHistory() throws {
        let model = try fixture(scale: 4)
        let original = try model.projectData()
        let undoCount = model.undoStack.count
        #expect(model.beginPixelSelectionMove(at: CGPoint(x: 9, y: 9)))
        for delta in [CGSize(width: 1, height: 0), CGSize(width: -1, height: 0), .zero] {
            model.updatePixelSelectionMove(by: delta)
        }
        model.finishPixelSelectionMove()
        #expect(try model.projectData() == original)
        #expect(model.undoStack.count == undoCount)
    }

    @Test func fractionalPartialSelectionPreservesUnselectedColorAndCompositesOnce() throws {
        let model = try fixture(scale: 2, greenMiddleColumn: true)
        model.document.selection = .rectangle(CGRect(x: 10, y: 8, width: 2, height: 6))
        model.nudgeSelectionOrSelectedLayer(by: CGSize(width: 1, height: 0))
        let layer = try #require(model.document.selectedLayer)
        #expect(layer.frame == CGRect(x: 8, y: 8, width: 6, height: 6))
        #expect(model.document.selection?.bounds == CGRect(x: 11, y: 8, width: 2, height: 6))
        let bytes = try #require(imageEditorRGBABytes(layer.image, width: 3, height: 3))
        let expectedRow: [UInt8] = [255, 0, 0, 255, 0, 128, 0, 128, 128, 128, 0, 255]
        for y in 0..<3 {
            #expect(Array(bytes[(y * 12)..<((y + 1) * 12)]) == expectedRow)
        }
    }

    @Test func fractionalSamplingUsesPremultipliedColorAndSelectionCoverage() {
        let source: [UInt8] = [128, 0, 0, 128, 0, 255, 0, 255, 255, 255, 255, 255]
        var background: [UInt8] = [0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255]
        ImageEditorFractionalPixelMove.composite(
            source: source, maskAlpha: [255, 128, 0], width: 3, height: 1,
            delta: CGSize(width: 0.5, height: 0), into: &background
        )
        #expect(background == [64, 0, 191, 255, 64, 64, 127, 255, 0, 64, 191, 255])
    }

    @Test func diagonalFractionalSamplingSplitsCoverageAcrossBothAxes() {
        var background = [UInt8](repeating: 0, count: 16)
        ImageEditorFractionalPixelMove.composite(
            source: [255, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            maskAlpha: [255, 0, 0, 0], width: 2, height: 2,
            delta: CGSize(width: 0.5, height: 0.5), into: &background
        )
        #expect(background == Array(repeating: [UInt8](arrayLiteral: 64, 0, 0, 64), count: 4).flatMap { $0 })
    }

    private func fixture(scale: Double, greenMiddleColumn: Bool = false) throws -> ImageEditorViewModel {
        let image = try #require(NSImage.rendered(size: CGSize(width: 3, height: 3)) { rect in
            NSColor.red.setFill()
            rect.fill()
            if greenMiddleColumn {
                NSColor.green.setFill()
                CGRect(x: 1, y: 0, width: 1, height: 3).fill()
            }
        })
        var layer = ImageEditorLayer.blank(name: "Scaled pixels", size: image.size)
        layer.image = image
        layer.frame = CGRect(x: 8, y: 8, width: 3 * scale, height: 3 * scale)
        let model = ImageEditorViewModel(sourceName: "scaled-nudge.png", image: .transparent(size: CGSize(width: 32, height: 32))) { _ in }
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        model.selectedTool = .move
        model.document.selection = .rectangle(layer.frame)
        return model
    }
}
