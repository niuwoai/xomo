import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSelectionMaskSamplingTests {
    @Test(arguments: [false, true], [1, 5])
    func creationKeepsFineSelectionAtCanvasPosition(hiding: Bool, scale: Int) throws {
        let model = fixture(scale: scale)
        let layer = model.document.layers[0]
        let rect = selectionRect(scale: scale)
        model.createRectSelection(from: rect.origin, to: CGPoint(x: rect.maxX, y: rect.maxY))
        if hiding { model.addLayerMaskHidingSelection() } else { model.addLayerMaskFromSelection() }
        let result = model.document.layers[0]
        let mask = try #require(result.mask)
        #expect(mask.size == layer.frame.size)
        #expect(result.image === layer.image)
        #expect(result.frame == layer.frame)
        let alpha = try #require(mask.alphaMask(width: Int(layer.frame.width), height: Int(layer.frame.height)))
        let local = rect.offsetBy(dx: -layer.frame.minX, dy: -layer.frame.minY)
        #expect(alpha.alpha == rectangleAlpha(size: layer.frame.size, rect: local, inverted: hiding))
        let rendered = try #require(model.document.compositedImage.alphaMask(width: 450, height: 400))
        #expect(rendered.alpha[Int(rect.minY) * 450 + Int(rect.minX)] == (hiding ? 0 : 255))
    }

    @Test(arguments: [false, true])
    func rasterSelectionPreservesSoftAlphaAndInversion(inverted: Bool) throws {
        let model = fixture()
        var alpha = [UInt8](repeating: 0, count: 450 * 400)
        alpha[102 * 450 + 121] = 64
        alpha[102 * 450 + 122] = 192
        let rect = CGRect(x: 121, y: 102, width: 2, height: 1)
        model.document.selection = .raster(mask: ImageEditorSelectionMask(width: 450, height: 400, alpha: alpha), bounds: rect)
        model.document.selection?.isInverted = inverted
        model.addLayerMaskFromSelection()
        let mask = try #require(model.document.layers[0].mask?.alphaMask(width: 400, height: 300))
        #expect(mask.alpha[72 * 400 + 101] == (inverted ? 191 : 64))
        #expect(mask.alpha[72 * 400 + 102] == (inverted ? 63 : 192))
        #expect(mask.alpha[73 * 400 + 101] == (inverted ? 255 : 0))
    }

    @Test func maskSelectionRoundTripKeepsOffCenterCanvasCoordinates() throws {
        let model = fixture()
        let rect = selectionRect()
        model.createRectSelection(from: rect.origin, to: CGPoint(x: rect.maxX, y: rect.maxY))
        model.addLayerMaskFromSelection()
        model.document.selection = nil
        model.loadSelectionFromLayerMask()
        let mask = try #require(model.document.selection?.rasterMask)
        #expect(mask.alpha == rectangleAlpha(size: model.document.canvasSize, rect: rect))
    }

    @Test(arguments: ["reveal", "hide", "intersect"], [false, true])
    func combiningSelectionKeepsFineDetails(action: String, highResolution: Bool) throws {
        let model = fixture()
        let size = highResolution ? CGSize(width: 400, height: 300) : CGSize(width: 80, height: 60)
        model.document.layers[0].mask = action == "reveal"
            ? .transparent(size: size) : .opaqueMask(size: size)
        let rect = selectionRect()
        model.createRectSelection(from: rect.origin, to: CGPoint(x: rect.maxX, y: rect.maxY))
        switch action {
        case "reveal": model.revealSelectionOnLayerMask()
        case "hide": model.hideSelectionOnLayerMask()
        default: model.intersectLayerMaskWithSelection()
        }
        func verifyFineDetails() throws {
            let mask = try #require(model.document.layers[0].mask)
            #expect(mask.size == CGSize(width: 400, height: 300))
            let alpha = try #require(mask.alphaMask(width: 400, height: 300))
            #expect(alpha.alpha == rectangleAlpha(size: CGSize(width: 400, height: 300), rect: rect.offsetBy(dx: -20, dy: -30), inverted: action == "hide"))
        }
        try verifyFineDetails()
    }

    @Test func creationAndCombinationUndoRedoPreserveProjectData() throws {
        let model = fixture()
        let rect = selectionRect()
        model.createRectSelection(from: rect.origin, to: CGPoint(x: rect.maxX, y: rect.maxY))
        let before = try model.projectData()
        model.addLayerMaskFromSelection()
        let created = try model.projectData()
        model.hideSelectionOnLayerMask()
        let hidden = try model.projectData()
        #expect(hidden != created)
        model.undo()
        #expect(try model.projectData() == created)
        model.undo()
        #expect(try model.projectData() == before)
        model.redo()
        #expect(try model.projectData() == created)
        model.redo()
        #expect(try model.projectData() == hidden)
        let restored = fixture()
        try restored.loadProjectData(created)
        #expect(restored.document.layers[0].mask?.size == CGSize(width: 400, height: 300))
    }

    @Test func selectionOutsideLayerCreatesTransparentMask() throws {
        let model = fixture()
        model.createRectSelection(from: CGPoint(x: 1, y: 1), to: CGPoint(x: 4, y: 5))
        model.addLayerMaskFromSelection()
        let mask = try #require(model.document.layers[0].mask?.alphaMask(width: 400, height: 300))
        #expect(mask.alpha.allSatisfy { $0 == 0 })
    }

    @Test func batchCreationSkipsLockedAndAlreadyMaskedLayers() throws {
        let model = fixture()
        var locked = model.document.layers[0]
        locked.id = UUID()
        locked.isLocked = true
        var masked = model.document.layers[0]
        masked.id = UUID()
        masked.mask = .opaqueMask(size: CGSize(width: 80, height: 60))
        model.document.layers += [locked, masked]
        model.document.selectedLayerIDs = Set(model.document.layers.map(\.id))
        let rect = selectionRect()
        model.createRectSelection(from: rect.origin, to: CGPoint(x: rect.maxX, y: rect.maxY))
        let history = model.document.history.count
        model.addLayerMaskFromSelection()
        #expect(model.document.layers[0].mask?.size == CGSize(width: 400, height: 300))
        #expect(model.document.layers[1].mask == nil)
        #expect(model.document.layers[2].mask === masked.mask)
        #expect(model.document.history.count == history + 1)
    }

    @Test func oversizedMaskAllocationDoesNotMutateLayerOrHistory() throws {
        let model = fixture()
        model.document.layers[0].frame.size = CGSize(width: 100_000, height: 100_000)
        model.createRectSelection(from: CGPoint(x: 30, y: 40), to: CGPoint(x: 33, y: 44))
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        model.addLayerMaskFromSelection()
        #expect(model.document.layers[0].mask == nil)
        #expect(try model.projectData() == before)
        #expect(model.undoStack.count == undoCount)
    }

    private func fixture(scale: Int = 5) -> ImageEditorViewModel {
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: CGSize(width: 450, height: 400))) { _ in }
        var layer = ImageEditorLayer.blank(name: "Selection mask", size: CGSize(width: 80, height: 60))
        layer.image = NSImage.rendered(size: layer.image.size) { rect in
            NSColor.red.setFill()
            rect.fill()
        } ?? layer.image
        layer.frame = CGRect(x: 20, y: 30, width: 80 * scale, height: 60 * scale)
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        return model
    }

    private func selectionRect(scale: Int = 5) -> CGRect {
        CGRect(x: 20 + 20 * scale + 1, y: 30 + 14 * scale + 2, width: 3, height: 4)
    }

    private func rectangleAlpha(size: CGSize, rect: CGRect, inverted: Bool = false) -> [UInt8] {
        let width = Int(size.width), height = Int(size.height)
        var alpha = [UInt8](repeating: inverted ? 255 : 0, count: width * height)
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) { alpha[y * width + x] = inverted ? 0 : 255 }
        }
        return alpha
    }
}
