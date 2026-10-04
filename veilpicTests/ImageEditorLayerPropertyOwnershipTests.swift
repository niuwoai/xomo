import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorLayerPropertyOwnershipTests {
    enum Property: CaseIterable {
        case opacity, fill, sourceBlack, sourceWhite, underlyingBlack, underlyingWhite, density, feather
    }
    enum Command: CaseIterable { case automationRename, automationOpacity, theme, rotation }
    enum Pending: CaseIterable { case none, pixelMove, maskProperty }
    struct InvalidArgument { let value: XomoJSONValue? }
    static let invalidValues: [XomoJSONValue?] = [nil, .null, .string("not a number"), .bool(true),
                                               .number(.nan), .number(.infinity), .number(-.infinity)]
    static let invalidArguments = invalidValues.map { InvalidArgument(value: $0) }
    struct Scenario { let property: Property; let changed: Bool }
    static let scenarios = Property.allCases.flatMap { property in
        [false, true].map { Scenario(property: property, changed: $0) }
    }
    struct Pair { let first: Property; let second: Property }
    static let pairs = Property.allCases.flatMap { first in
        Property.allCases.filter { $0 != first }.map { Pair(first: first, second: $0) }
    }

    @Test(arguments: invalidArguments, Pending.allCases)
    func invalidOpacityRequestPreservesCompleteState(argument: InvalidArgument, pending: Pending) throws {
        let model = try fixture()
        model.selectXomoComponentTheme(.softMobile)
        model.undo()
        switch pending {
        case .none: break
        case .pixelMove:
            try #require(model.beginPixelSelectionMove())
            model.updatePixelSelectionMove(by: CGSize(width: 3, height: -2))
        case .maskProperty:
            begin(.density, in: model)
            change(.density, in: model)
        }
        let before = try snapshot(model)
        let hadPixelMove = model.pixelSelectionMoveTransaction != nil
        let registry = XomoAutomationRegistry.shared
        registry.register(model)
        defer { registry.unregister(model) }
        var arguments: [String: XomoJSONValue] = [:]
        if let value = argument.value { arguments["opacity"] = value }
        let response = registry.execute(XomoAutomationWireRequest(token: "test-only", operation: "call",
            name: "xomo.layer.set_opacity", arguments: arguments))
        #expect(!response.ok)
        #expect(try snapshot(model) == before)
        #expect((model.pixelSelectionMoveTransaction != nil) == hadPixelMove)
    }

    @Test(arguments: scenarios, Command.allCases)
    func ordinaryCommandOwnsUndoAfterPropertyPreview(scenario: Scenario, command: Command) throws {
        let model = try fixture()
        model.selectXomoComponentTheme(.softMobile)
        model.undo()
        let original = try model.projectData()
        let reference = try fixture()
        reference.document = model.document
        reference.xomoComponentTheme = model.xomoComponentTheme
        begin(scenario.property, in: reference)
        if scenario.changed { change(scenario.property, in: reference) }
        end(scenario.property, in: reference)
        let preview = try reference.projectData()
        try #require((preview != original) == scenario.changed)
        try apply(command, to: reference)
        let expected = try reference.projectData()

        begin(scenario.property, in: model)
        if scenario.changed { change(scenario.property, in: model) }
        try apply(command, to: model)
        #expect(try model.projectData() == expected)
        #expect(model.undoStack.count == (scenario.changed ? 2 : 1) && model.redoStack.isEmpty)
        let committed = try snapshot(model)
        end(scenario.property, in: model) // delayed slider mouse-up must be harmless
        #expect(try snapshot(model) == committed)
        model.undo()
        #expect(try model.projectData() == preview)
        if scenario.changed {
            model.undo()
            #expect(try model.projectData() == original)
            model.redo()
            #expect(try model.projectData() == preview)
        }
        model.redo()
        #expect(try model.projectData() == expected)
    }

    @Test(arguments: pairs, [false, true])
    func anotherPropertyGetsExclusiveSnapshot(pair: Pair, changed: Bool) throws {
        let model = try fixture()
        let original = try model.projectData()
        let reference = try fixture()
        reference.document = model.document
        begin(pair.first, in: reference)
        if changed { change(pair.first, in: reference) }
        end(pair.first, in: reference)
        let first = try reference.projectData()
        begin(pair.second, in: reference)
        change(pair.second, in: reference)
        end(pair.second, in: reference)
        let expected = try reference.projectData()

        begin(pair.first, in: model)
        if changed { change(pair.first, in: model) }
        begin(pair.second, in: model)
        change(pair.second, in: model)
        end(pair.second, in: model)
        let committed = try snapshot(model)
        end(pair.first, in: model)
        #expect(try snapshot(model) == committed)
        #expect(try model.projectData() == expected)
        #expect(model.undoStack.count == (changed ? 2 : 1))
        model.undo()
        #expect(try model.projectData() == first)
        if changed {
            model.undo()
            #expect(try model.projectData() == original)
            model.redo()
        }
        model.redo()
        #expect(try model.projectData() == expected)
    }

    @Test(arguments: scenarios, [false, true])
    func historyCommandCancelsOnlyPropertyPreview(scenario: Scenario, redo: Bool) throws {
        let model = try fixture()
        model.selectXomoComponentTheme(.softMobile)
        let pending = try model.projectData()
        model.undo()
        let original = try snapshot(model)
        begin(scenario.property, in: model)
        if scenario.changed { change(scenario.property, in: model) }
        #expect(model.canUndo && model.canRedo)
        if redo { model.redo() } else { model.undo() }
        #expect(try snapshot(model) == original)
        end(scenario.property, in: model)
        #expect(try snapshot(model) == original)
        model.redo()
        #expect(try model.projectData() == pending)
        #expect(model.xomoComponentTheme == .softMobile)
    }

    @Test(arguments: Property.allCases, [false, true])
    func historyResetOrReloadDiscardsPropertyOwnership(property: Property, reload: Bool) throws {
        let model = try fixture()
        model.selectXomoComponentTheme(.softMobile)
        model.undo()
        let saved = try model.projectData()
        begin(property, in: model)
        change(property, in: model)
        if reload { try model.loadProjectData(saved) } else { model.clearUndoHistory() }
        let cleared = try snapshot(model)
        end(property, in: model)
        #expect(try snapshot(model) == cleared)
        #expect(model.undoStack.isEmpty && model.redoStack.isEmpty)
    }

    @Test func delayedBlendIfEndDoesNotFinishAnotherActiveSlider() throws {
        let properties: [Property] = [.sourceBlack, .sourceWhite, .underlyingBlack, .underlyingWhite]
        for first in properties {
            for second in properties where second != first {
                for changedFirst in [false, true] {
                    let model = try fixture()
                    let reference = try fixture()
                    reference.document = model.document
                    let original = try model.projectData()
                    begin(first, in: reference)
                    if changedFirst { change(first, in: reference) }
                    end(first, in: reference)
                    let firstCommitted = try reference.projectData()
                    begin(second, in: reference)
                    change(second, in: reference)
                    end(second, in: reference)
                    let expected = try reference.projectData()

                    begin(first, in: model)
                    if changedFirst { change(first, in: model) }
                    begin(second, in: model)
                    change(second, in: model)
                    let pending = try snapshot(model)
                    end(first, in: model) // old mouse-up arrives before the new one
                    #expect(try snapshot(model) == pending)
                    #expect(model.hasActiveLayerPropertyEdit)
                    end(second, in: model)
                    #expect(!model.hasActiveLayerPropertyEdit)
                    #expect(try model.projectData() == expected)
                    #expect(model.undoStack.count == (changedFirst ? 2 : 1))
                    model.undo()
                    #expect(try model.projectData() == firstCommitted)
                    if changedFirst {
                        model.undo()
                        #expect(try model.projectData() == original)
                        model.redo()
                    }
                    model.redo()
                    #expect(try model.projectData() == expected)
                }
            }
        }
    }

    private func fixture() throws -> ImageEditorViewModel {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        let index = try #require(model.document.selectedLayerIndex)
        model.document.layers[index].mask = .opaqueMask(size: model.document.canvasSize)
        model.isEditingLayerMask = false
        model.document.isGuideSnappingEnabled = false
        model.clearUndoHistory()
        return model
    }

    private func apply(_ command: Command, to model: ImageEditorViewModel) throws {
        switch command {
        case .automationRename, .automationOpacity:
            let registry = XomoAutomationRegistry.shared
            registry.register(model)
            defer { registry.unregister(model) }
            let name = command == .automationRename ? "xomo.layer.rename" : "xomo.layer.set_opacity"
            let arguments: [String: XomoJSONValue] = command == .automationRename
                ? ["name": .string("Rename after slider preview")] : ["opacity": .number(0.35)]
            let response = registry.execute(XomoAutomationWireRequest(token: "test-only", operation: "call",
                name: name, arguments: arguments))
            try #require(response.ok)
        case .theme: model.selectXomoComponentTheme(.softMobile)
        case .rotation:
            let frame = try #require(model.selectedLayerTransformFrame)
            model.beginRotatingSelectedLayer(from: CGPoint(x: frame.midX, y: frame.minY - 24))
            model.rotateSelectedLayer(to: CGPoint(x: frame.maxX + 40, y: frame.minY - 40))
            model.finishRotatingSelectedLayer()
        }
    }

    private func begin(_ property: Property, in model: ImageEditorViewModel) {
        switch property {
        case .opacity: model.beginSelectedLayerOpacityChange()
        case .fill: model.beginSelectedLayerFillOpacityChange()
        case .sourceBlack: model.beginSelectedLayerBlendIfSourceBlackChange()
        case .sourceWhite: model.beginSelectedLayerBlendIfSourceWhiteChange()
        case .underlyingBlack: model.beginSelectedLayerBlendIfUnderlyingBlackChange()
        case .underlyingWhite: model.beginSelectedLayerBlendIfUnderlyingWhiteChange()
        case .density: model.beginSelectedLayerMaskDensityChange()
        case .feather: model.beginSelectedLayerMaskFeatherChange()
        }
    }

    private func change(_ property: Property, in model: ImageEditorViewModel) {
        switch property {
        case .opacity: model.setSelectedLayerOpacity(0.6)
        case .fill: model.setSelectedLayerFillOpacity(0.6)
        case .sourceBlack: model.setSelectedLayerBlendIfSourceBlack(0.2)
        case .sourceWhite: model.setSelectedLayerBlendIfSourceWhite(0.8)
        case .underlyingBlack: model.setSelectedLayerBlendIfUnderlyingBlack(0.2)
        case .underlyingWhite: model.setSelectedLayerBlendIfUnderlyingWhite(0.8)
        case .density: model.setSelectedLayerMaskDensity(0.6)
        case .feather: model.setSelectedLayerMaskFeather(2)
        }
    }

    private func end(_ property: Property, in model: ImageEditorViewModel) {
        switch property {
        case .opacity: model.commitSelectedLayerOpacityChange()
        case .fill: model.commitSelectedLayerFillOpacityChange()
        case .sourceBlack: model.commitSelectedLayerBlendIfChange(.sourceBlack)
        case .sourceWhite: model.commitSelectedLayerBlendIfChange(.sourceWhite)
        case .underlyingBlack: model.commitSelectedLayerBlendIfChange(.underlyingBlack)
        case .underlyingWhite: model.commitSelectedLayerBlendIfChange(.underlyingWhite)
        case .density: model.commitSelectedLayerMaskDensityChange()
        case .feather: model.commitSelectedLayerMaskFeatherChange()
        }
    }

    private func documentData(_ document: ImageEditorDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(ImageEditorProjectDocument(document: document))
    }

    private func snapshot(_ model: ImageEditorViewModel) throws -> Snapshot {
        Snapshot(project: try model.projectData(), undo: try model.undoStack.map(documentData),
            redo: try model.redoStack.map(documentData),
            undoThemes: model.undoTransactionState.undoThemes.map(\.theme),
            redoThemes: model.undoTransactionState.redoThemes.map(\.theme),
            undoTokens: model.undoTransactionState.undoThemes.map(\.tokenSnapshot),
            redoTokens: model.undoTransactionState.redoThemes.map(\.tokenSnapshot),
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
        let canUndo: Bool
        let canRedo: Bool
    }
}
