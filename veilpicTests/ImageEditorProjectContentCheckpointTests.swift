import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorProjectContentCheckpointTests {
    private enum Mutation: CaseIterable {
        case none, removeSelection, removeSavedSelection, selectionAlpha, selectionPoint, selectionFlags
        case savedAlpha, channelAlpha, channelName, channelOrder, channelKind, spotComponents
        case imagePayload, maskPayload, frame, layerComp, history, sampler, signedZero, unicodeScalars
    }

    @Test(arguments: Mutation.allCases)
    private func checkpointNeverContradictsFullProjectBytes(mutation: Mutation) throws {
        let model = try makeModel()
        let original = try model.projectDocument()
        let checkpoint = try ImageEditorProjectContentCheckpoint(project: original)
        var changed = original
        switch mutation {
        case .none: break
        case .removeSelection: changed.selection = nil
        case .removeSavedSelection: changed.savedSelection = nil
        case .selectionAlpha: changed.selection?.rasterMask?.alpha[4_095] = 1
        case .selectionPoint: changed.selection?.points[0].x += 0.05
        case .selectionFlags: changed.selection?.isInverted.toggle()
        case .savedAlpha: changed.savedSelection?.rasterMask?.alpha[4_095] = 1
        case .channelAlpha: changed.alphaChannels[0].mask.alpha[4_095] = 1
        case .channelName: changed.alphaChannels[0].name = "Different stored name"
        case .channelOrder: changed.alphaChannels.swapAt(0, 1)
        case .channelKind: changed.alphaChannels[0].kind = .alpha
        case .spotComponents: changed.alphaChannels[0].spotColor?.components[0] += 1
        case .imagePayload: changed.layers[0].imageData = Data([1, 2, 3])
        case .maskPayload: changed.layers[0].maskData = Data([1, 2, 3])
        case .frame: changed.layers[0].frame.origin.x += 0.05
        case .layerComp: changed.layerComps?[0].name = "Changed comp"
        case .history: changed.historyTitles.append("Changed history")
        case .sampler: changed.colorSamplerIgnoresAdjustmentLayers = true
        case .signedZero: changed.selection?.points[0].x = CGFloat(Double(bitPattern: 0x8000_0000_0000_0000))
        case .unicodeScalars: changed.alphaChannels[0].name = "e\u{301}"
        }
        let result = try checkpoint.matches(changed)
        let fullMatch = try encoded(original) == encoded(changed)
        if let result { #expect(result == fullMatch) }
        // A changed excluded value is deliberately undecided, not declared clean.
        if [.signedZero, .unicodeScalars].contains(mutation) { #expect(result == nil) }
        #expect(try checkpoint.matches(original) == true)
    }

    @Test func signedZeroAndUnicodeScalarChangesUseExactFallbackInModel() throws {
        let model = try makeModel()
        model.resetProjectSaveBaseline()
        let baseline = try model.projectData()
        model.document.selection?.points[0].x = CGFloat(Double(bitPattern: 0x8000_0000_0000_0000))
        let signedZeroDirty = try model.projectData() != baseline
        #expect(model.hasUnsavedProjectChanges == signedZeroDirty)
        model.document.selection?.points[0].x = 0
        #expect(!model.hasUnsavedProjectChanges)
        model.document.alphaChannels[0].name = "e\u{301}"
        #expect(model.document.alphaChannels[0].name == "\u{e9}")
        let scalarDirty = try model.projectData() != baseline
        #expect(model.hasUnsavedProjectChanges == scalarDirty)
        model.document.alphaChannels[0].name = "\u{e9}"
        #expect(!model.hasUnsavedProjectChanges)
    }

    @Test func copiedMaskValuesStayStableAcrossEditsAndExactRestoration() throws {
        let model = try makeModel()
        model.resetProjectSaveBaseline()
        let baseline = try model.projectData()
        let selection = model.document.selection
        let channels = model.document.alphaChannels
        model.document.selection?.rasterMask?.alpha[4_095] = 1
        #expect(model.hasUnsavedProjectChanges)
        model.document.selection = selection
        #expect(!model.hasUnsavedProjectChanges)
        model.document.alphaChannels[1].mask.alpha[4_095] = 1
        #expect(model.hasUnsavedProjectChanges)
        model.document.alphaChannels = channels
        #expect(try model.projectData() == baseline && !model.hasUnsavedProjectChanges)
    }

    @Test func legacyBaselineAndClearedStateRetainConservativeFallback() throws {
        let model = try makeModel()
        let baseline = try model.projectData()
        model.updateProjectSaveBaseline(baseline)
        #expect(!model.hasUnsavedProjectChanges)
        model.document.layers[0].opacity = 0.5
        #expect(model.hasUnsavedProjectChanges)
        model.document.layers[0].opacity = 1
        #expect(!model.hasUnsavedProjectChanges)
        model.updateProjectSaveBaseline(nil)
        #expect(model.hasUnsavedProjectChanges)
        model.resetProjectSaveBaseline()
        #expect(!model.hasUnsavedProjectChanges)
        #expect(model.projectHasUnsavedChanges(rasterEncoder: { _ in nil }))
        model.document.selection?.points[0].x = .nan
        #expect(model.hasUnsavedProjectChanges)
    }

    private func makeModel() throws -> ImageEditorViewModel {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        let mask = ImageEditorSelectionMask(width: 64, height: 64,
            alpha: [UInt8](repeating: 128, count: 4_096))
        model.document.selection = ImageEditorSelection(points: [.zero, CGPoint(x: 64, y: 64)],
            isPolygon: false, rasterMask: mask)
        model.document.savedSelection = model.document.selection
        model.document.alphaChannels = [
            ImageEditorAlphaChannel(name: "\u{e9}", mask: mask, kind: .spot,
                spotColor: ImageEditorPSDSpotColor(components: [1, 2, 3, 4])),
            ImageEditorAlphaChannel(name: "Other alpha", mask: mask)
        ]
        model.addLayerComp(named: "Stored state")
        return model
    }

    private func encoded(_ project: ImageEditorProjectDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(project)
    }
}
