import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorMaskFeatherSamplingTests {
    @Test(arguments: [2.0, 24.0], [0, 1, 2, 3])
    func promotionPreservesFeatherWidths(feather: Double, geometry: Int) throws {
        let model = fixture(feather: feather, vertical: geometry % 2 == 1, nonuniform: geometry >= 2)
        let before = try sampledMask(model)
        let coarse = try #require(model.document.layers[0].effectiveRasterMask?.alphaMask(width: 80, height: 60))
        model.revealSelectionOnLayerMask()
        let layer = model.document.layers[0]
        #expect(layer.mask?.size == CGSize(width: 400, height: 300))
        #expect(layer.maskFeather == feather)
        #expect(layer.maskFeatherSamplingScale == 5)
        let after = try sampledMask(model)
        // The legacy coarse grid quantizes its edge. Allow its sampling error,
        // but not the fivefold physical narrowing caused by an unscaled radius.
        let largestDelta = zip(before.alpha, after.alpha).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(largestDelta <= coarseSamplingTolerance(coarse))
        let mask = try #require(layer.mask)
        let expected = try #require(mask.blurred(radius: feather * 5)?.alphaMask(width: 400, height: 300))
        #expect(try #require(layer.effectiveRasterMask?.alphaMask(width: 400, height: 300)) == expected)
    }

    @Test func repeatedEditingDoesNotMultiplyFeatherAgainOrAddEmptyUndo() throws {
        let model = fixture()
        model.revealSelectionOnLayerMask()
        let data = try model.projectData()
        let undoCount = model.undoStack.count
        model.revealSelectionOnLayerMask()
        #expect(model.document.layers[0].maskFeatherSamplingScale == 5)
        #expect(try model.projectData() == data)
        #expect(model.undoStack.count == undoCount)
    }

    @Test func promotionRoundTripsThroughProjectAndUndoRedo() throws {
        let model = fixture()
        let before = try model.projectData()
        let legacy = fixture()
        try legacy.loadProjectData(before)
        #expect(legacy.document.layers[0].maskFeatherSamplingScale == nil)
        model.revealSelectionOnLayerMask()
        let after = try model.projectData()
        let pixels = try sampledMask(model)
        let restored = fixture()
        try restored.loadProjectData(after)
        #expect(restored.document.layers[0].maskFeatherSamplingScale == 5)
        #expect(try sampledMask(restored) == pixels)
        model.undo()
        #expect(try model.projectData() == before)
        model.redo()
        #expect(try model.projectData() == after)
    }

    @Test func layerCompRestoresFeatherSamplingAndDetectsChanges() throws {
        let model = fixture()
        model.revealSelectionOnLayerMask()
        model.addLayerComp(named: "Promoted mask")
        let id = try #require(model.document.selectedLayerCompID)
        #expect(model.isLayerCompApplied(id))
        model.document.layers[0].maskFeatherSamplingScale = 1
        #expect(!model.isLayerCompApplied(id))
        #expect(model.applyLayerComp(id))
        #expect(model.document.layers[0].maskFeatherSamplingScale == 5)
        let restored = fixture()
        try restored.loadProjectData(model.projectData())
        restored.document.layers[0].maskFeatherSamplingScale = 1
        #expect(restored.applyLayerComp(id))
        #expect(restored.document.layers[0].maskFeatherSamplingScale == 5)
    }

    @Test func applyingMaskBakesFeatherOnceAndClearsSamplingMetadata() throws {
        let model = fixture()
        model.revealSelectionOnLayerMask()
        let before = try #require(model.document.compositedImage.qingtuPNGData())
        model.applyLayerMask()
        #expect(model.document.layers[0].mask == nil)
        #expect(model.document.layers[0].maskFeatherSamplingScale == nil)
        #expect(try #require(model.document.compositedImage.qingtuPNGData()) == before)
    }

    @Test func copiedPromotedMaskRetainsItsGridAndFeatherUnits() throws {
        let model = fixture()
        model.revealSelectionOnLayerMask()
        let source = model.document.layers[0]
        var target = source
        target.id = UUID()
        target.mask = nil
        model.document.layers.append(target)
        model.document.selectedLayerIDs = [source.id, target.id]
        model.document.selectedLayerID = source.id
        model.copyLayerMaskToSelectedLayers()
        #expect(model.document.layers[1].mask?.size == source.mask?.size)
        #expect(model.document.layers[1].maskFeatherSamplingScale == 5)
        #expect(model.document.layers[1].effectiveRasterMask?.qingtuPNGData() == source.effectiveRasterMask?.qingtuPNGData())
    }

    @Test func groupMaskPromotionUsesUniformSamplingForCanvasCoordinates() throws {
        let model = fixture()
        var group = ImageEditorLayer.group(name: "Group", size: model.document.canvasSize)
        group.mask = .opaqueMask(size: CGSize(width: 80, height: 60))
        group.maskFeather = 2
        model.document.layers[0].groupID = group.id
        model.document.layers.append(group)
        model.selectLayer(group.id)
        model.revealSelectionOnLayerMask()
        #expect(model.document.layers[1].mask?.size == CGSize(width: 560, height: 420))
        #expect(model.document.layers[1].maskFeatherSamplingScale == 7)
        #expect(model.document.layers[1].maskFeather == 2)
    }

    @Test func invalidPersistedSamplingScalesUseLegacyUnits() {
        for value in [Double.nan, .infinity, -1, 0, Double.greatestFiniteMagnitude] {
            #expect(ImageEditorMaskSampling.featherScale(value) == 1)
        }
        #expect(ImageEditorMaskSampling.featherScale(nil) == 1)
        #expect(ImageEditorMaskSampling.featherScale(5) == 5)
    }

    private func fixture(feather: Double = 2, vertical: Bool = false, nonuniform: Bool = false) -> ImageEditorViewModel {
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: CGSize(width: 450, height: 400))) { _ in }
        var layer = ImageEditorLayer.blank(name: "Feather", size: CGSize(width: 80, height: 60))
        layer.image = .opaqueMask(size: layer.image.size)
        var alpha = [UInt8](repeating: 0, count: 80 * 60)
        for y in 0..<60 { for x in 0..<80 where vertical ? y < 30 : x < 40 { alpha[y * 80 + x] = 255 } }
        layer.mask = NSImage.alphaMaskImage(width: 80, height: 60, alpha: alpha)
        layer.maskFeather = feather
        layer.frame = CGRect(x: 20, y: 30, width: 400, height: nonuniform ? 240 : 300)
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        model.createRectSelection(from: CGPoint(x: 31, y: 41), to: CGPoint(x: 34, y: 44))
        return model
    }

    private func sampledMask(_ model: ImageEditorViewModel) throws -> ImageEditorSelectionMask {
        let layer = model.document.layers[0]
        return try #require(layer.effectiveRasterMask?.alphaMask(width: Int(layer.frame.width), height: Int(layer.frame.height)))
    }

    private func coarseSamplingTolerance(_ mask: ImageEditorSelectionMask) -> Int {
        var largestStep = 0
        for y in 0..<mask.height {
            for x in 0..<mask.width {
                let value = Int(mask.alpha[y * mask.width + x])
                if x + 1 < mask.width { largestStep = max(largestStep, abs(value - Int(mask.alpha[y * mask.width + x + 1]))) }
                if y + 1 < mask.height { largestStep = max(largestStep, abs(value - Int(mask.alpha[(y + 1) * mask.width + x]))) }
            }
        }
        // Nearest sampling of the old grid has up to half a sample-step error;
        // allow two alpha levels for the two independently quantized filters.
        return (largestStep + 1) / 2 + 2
    }
}
