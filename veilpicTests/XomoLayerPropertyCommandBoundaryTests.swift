import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct XomoLayerPropertyCommandBoundaryTests {
    enum Property: String, CaseIterable {
        case fillOpacity, blendIfSourceBlack, blendIfSourceWhite
        case blendIfUnderlyingBlack, blendIfUnderlyingWhite, maskDensity, maskFeather

        var preview: Double {
            switch self {
            case .blendIfSourceBlack, .blendIfUnderlyingBlack: return 0.2
            case .blendIfSourceWhite, .blendIfUnderlyingWhite: return 0.8
            case .maskFeather: return 2
            default: return 0.6
            }
        }
        var command: Double {
            switch self {
            case .blendIfSourceBlack, .blendIfUnderlyingBlack: return 0.35
            case .blendIfSourceWhite, .blendIfUnderlyingWhite: return 0.7
            case .maskFeather: return 4
            default: return 0.35
            }
        }
    }
    enum Pending: CaseIterable { case none, pixelMove, opacity }
    struct InvalidScenario { let value: XomoJSONValue?; let pending: Pending }
    static let invalidValues: [XomoJSONValue?] = [nil, .null, .string("not a number"), .bool(true),
        .number(.nan), .number(.infinity), .number(-.infinity)]
    static let invalidScenarios = invalidValues.flatMap { value in
        Pending.allCases.map { InvalidScenario(value: value, pending: $0) }
    }

    @Test(arguments: Property.allCases, invalidScenarios)
    func invalidPropertyCommandPreservesCompleteState(
        property: Property, scenario: InvalidScenario
    ) throws {
        let model = try fixture()
        model.selectXomoComponentTheme(.softMobile)
        model.undo()
        switch scenario.pending {
        case .none: break
        case .pixelMove:
            try #require(model.beginPixelSelectionMove())
            model.updatePixelSelectionMove(by: CGSize(width: 3, height: -2))
        case .opacity:
            model.beginSelectedLayerOpacityChange()
            model.setSelectedLayerOpacity(0.6)
        }
        let before = try snapshot(model)
        let response = execute(property, value: scenario.value, in: model)
        #expect(!response.ok)
        #expect(try snapshot(model) == before)
    }

    @Test(arguments: Property.allCases, [false, true])
    func samePropertyCommandOwnsIndependentUndo(property: Property, changedPreview: Bool) throws {
        let model = try fixture()
        model.selectXomoComponentTheme(.softMobile)
        model.undo()
        let original = try model.projectData()
        let reference = try fixture()
        reference.document = model.document
        reference.xomoComponentTheme = model.xomoComponentTheme
        begin(property, in: reference)
        if changedPreview { change(property, to: property.preview, in: reference) }
        end(property, in: reference)
        let preview = try reference.projectData()
        try #require((preview != original) == changedPreview)
        begin(property, in: model)
        if changedPreview { change(property, to: property.preview, in: model) }
        #expect(execute(property, value: .number(property.command), in: model).ok)
        let committed = try snapshot(model)
        #expect(!model.hasActiveLayerPropertyEdit)
        #expect(model.undoStack.count == (changedPreview ? 2 : 1))
        end(property, in: model)
        #expect(try snapshot(model) == committed)
        model.undo()
        #expect(try model.projectData() == preview)
        if changedPreview {
            model.undo()
            #expect(try model.projectData() == original)
            model.redo()
            #expect(try model.projectData() == preview)
        }
        model.redo()
        #expect(try snapshot(model).project == committed.project)
    }

    @Test(arguments: Property.allCases)
    func sameValueIdleCommandPreservesRedo(property: Property) throws {
        let model = try fixture()
        model.selectXomoComponentTheme(.softMobile)
        model.undo()
        let before = try snapshot(model)
        #expect(execute(property, value: .number(try value(property, in: model)), in: model).ok)
        #expect(try snapshot(model) == before)
    }

    @Test(arguments: Property.allCases, [-Double.greatestFiniteMagnitude, -1, 2, Double.greatestFiniteMagnitude])
    func finiteOutOfRangeKeepsExistingClamp(property: Property, requested: Double) throws {
        let model = try fixture()
        model.selectXomoComponentTheme(.softMobile)
        model.undo()
        let original = try model.projectData()
        let reference = try fixture()
        reference.document = model.document
        reference.xomoComponentTheme = model.xomoComponentTheme
        begin(property, in: reference)
        change(property, to: requested, in: reference)
        end(property, in: reference)
        let expected = try reference.projectData()
        #expect(execute(property, value: .number(requested), in: model).ok)
        #expect(try model.projectData() == expected)
        #expect(!model.hasActiveLayerPropertyEdit)
        #expect(model.undoStack.count == (expected == original ? 0 : 1))
        #expect(model.redoStack.count == (expected == original ? 1 : 0))
        if expected != original {
            model.undo()
            #expect(try model.projectData() == original)
            model.redo()
            #expect(try model.projectData() == expected)
        }
    }

    private func value(_ property: Property, in model: ImageEditorViewModel) throws -> Double {
        let layer = try #require(model.document.selectedLayer)
        switch property {
        case .fillOpacity: return layer.fillOpacity
        case .blendIfSourceBlack: return layer.blendIfSourceBlack
        case .blendIfSourceWhite: return layer.blendIfSourceWhite
        case .blendIfUnderlyingBlack: return layer.blendIfUnderlyingBlack
        case .blendIfUnderlyingWhite: return layer.blendIfUnderlyingWhite
        case .maskDensity: return layer.maskDensity
        case .maskFeather: return layer.maskFeather
        }
    }

    private func fixture() throws -> ImageEditorViewModel {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        let index = try #require(model.document.selectedLayerIndex)
        model.document.layers[index].mask = .opaqueMask(size: model.document.canvasSize)
        model.clearUndoHistory()
        return model
    }

    private func execute(_ property: Property, value: XomoJSONValue?, in model: ImageEditorViewModel)
        -> XomoAutomationWireResponse {
        let registry = XomoAutomationRegistry.shared
        registry.register(model)
        defer { registry.unregister(model) }
        var arguments: [String: XomoJSONValue] = ["property": .string(property.rawValue)]
        if let value { arguments["value"] = value }
        return registry.execute(XomoAutomationWireRequest(token: "test-only", operation: "call",
            name: "xomo.layer.properties", arguments: arguments))
    }

    private func begin(_ property: Property, in model: ImageEditorViewModel) {
        switch property {
        case .fillOpacity: model.beginSelectedLayerFillOpacityChange()
        case .blendIfSourceBlack: model.beginSelectedLayerBlendIfSourceBlackChange()
        case .blendIfSourceWhite: model.beginSelectedLayerBlendIfSourceWhiteChange()
        case .blendIfUnderlyingBlack: model.beginSelectedLayerBlendIfUnderlyingBlackChange()
        case .blendIfUnderlyingWhite: model.beginSelectedLayerBlendIfUnderlyingWhiteChange()
        case .maskDensity: model.beginSelectedLayerMaskDensityChange()
        case .maskFeather: model.beginSelectedLayerMaskFeatherChange()
        }
    }

    private func change(_ property: Property, to value: Double, in model: ImageEditorViewModel) {
        switch property {
        case .fillOpacity: model.setSelectedLayerFillOpacity(value)
        case .blendIfSourceBlack: model.setSelectedLayerBlendIfSourceBlack(value)
        case .blendIfSourceWhite: model.setSelectedLayerBlendIfSourceWhite(value)
        case .blendIfUnderlyingBlack: model.setSelectedLayerBlendIfUnderlyingBlack(value)
        case .blendIfUnderlyingWhite: model.setSelectedLayerBlendIfUnderlyingWhite(value)
        case .maskDensity: model.setSelectedLayerMaskDensity(value)
        case .maskFeather: model.setSelectedLayerMaskFeather(value)
        }
    }

    private func end(_ property: Property, in model: ImageEditorViewModel) {
        switch property {
        case .fillOpacity: model.commitSelectedLayerFillOpacityChange()
        case .maskDensity: model.commitSelectedLayerMaskDensityChange()
        case .maskFeather: model.commitSelectedLayerMaskFeatherChange()
        default: model.commitSelectedLayerBlendIfChange()
        }
    }

    private func encode(_ document: ImageEditorDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(ImageEditorProjectDocument(document: document))
    }

    private func snapshot(_ model: ImageEditorViewModel) throws -> Snapshot {
        Snapshot(project: try model.projectData(), undo: try model.undoStack.map(encode),
            redo: try model.redoStack.map(encode), undoThemes: model.undoTransactionState.undoThemes.map(\.theme),
            redoThemes: model.undoTransactionState.redoThemes.map(\.theme),
            undoTokens: model.undoTransactionState.undoThemes.map(\.tokenSnapshot),
            redoTokens: model.undoTransactionState.redoThemes.map(\.tokenSnapshot),
            propertyActive: model.hasActiveLayerPropertyEdit,
            pixelActive: model.pixelSelectionMoveTransaction != nil,
            canUndo: model.canUndo, canRedo: model.canRedo)
    }

    private struct Snapshot: Equatable {
        let project: Data
        let undo: [Data]
        let redo: [Data]
        let undoThemes: [XomoComponentTheme]
        let redoThemes: [XomoComponentTheme]
        let undoTokens: [XomoComponentThemeTokenSnapshot?]
        let redoTokens: [XomoComponentThemeTokenSnapshot?]
        let propertyActive: Bool
        let pixelActive: Bool
        let canUndo: Bool
        let canRedo: Bool
    }
}
