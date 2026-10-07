import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorLayerPropertyGestureTests {
    enum Interruption: CaseIterable { case undo, redo, clear, reload, rename, theme, automation }
    struct Pair {
        let first: ImageEditorLayerGestureProperty
        let second: ImageEditorLayerGestureProperty
    }
    static let pairs = ImageEditorLayerGestureProperty.allCases.flatMap { first in
        ImageEditorLayerGestureProperty.allCases.map { Pair(first: first, second: $0) }
    }

    @Test(arguments: ImageEditorLayerGestureProperty.allCases, Interruption.allCases)
    func oldCallbacksCannotWriteAfterInterruption(property: ImageEditorLayerGestureProperty, interruption: Interruption) throws {
        let model = try fixture()
        let saved = try model.projectData()
        let callbacks = try #require(model.makeLayerPropertyGestureCallbacks(property))
        callbacks.update(value(for: property))
        switch interruption {
        case .undo: model.undo()
        case .redo: model.redo()
        case .clear: model.clearUndoHistory()
        case .reload: try model.loadProjectData(saved)
        case .rename: model.renameSelectedLayer(to: "After gesture")
        case .theme: model.selectXomoComponentTheme(.softMobile)
        case .automation:
            let registry = XomoAutomationRegistry.shared
            registry.register(model)
            defer { registry.unregister(model) }
            let response = registry.execute(XomoAutomationWireRequest(token: "test-only", operation: "call",
                name: "xomo.layer.set_opacity", arguments: ["opacity": .number(0.35)]))
            try #require(response.ok)
        }
        let before = try snapshot(model)
        callbacks.update(value(for: property, next: true))
        callbacks.finish()
        #expect(try snapshot(model) == before)
        #expect(!model.hasActiveLayerPropertyEdit)
    }

    @Test(arguments: pairs)
    func oldValueAndEndCannotOwnNewGesture(pair: Pair) throws {
        let model = try fixture()
        let original = try model.projectData()
        let old = try #require(model.makeLayerPropertyGestureCallbacks(pair.first))
        old.update(value(for: pair.first))
        let current = try #require(model.makeLayerPropertyGestureCallbacks(pair.second))
        let firstCommitted = try model.projectData()
        current.update(value(for: pair.second, next: true))
        let pending = try snapshot(model)
        old.update(value(for: pair.first, next: true))
        old.finish()
        #expect(try snapshot(model) == pending)
        #expect(model.hasActiveLayerPropertyEdit)
        current.finish()
        let expected = try model.projectData()
        #expect(!model.hasActiveLayerPropertyEdit)
        #expect(model.undoStack.count == 2)
        model.undo()
        #expect(try model.projectData() == firstCommitted)
        model.undo()
        #expect(try model.projectData() == original)
        model.redo()
        model.redo()
        #expect(try model.projectData() == expected)
    }

    @Test func foreignModelAndInvalidValuesCannotUseGesture() throws {
        let model = try fixture()
        let other = try fixture()
        let gesture = try #require(model.beginLayerPropertyGesture(.opacity))
        let before = try snapshot(model)
        let otherBefore = try snapshot(other)
        #expect(!other.updateLayerPropertyGesture(gesture, value: 0.2))
        #expect(!other.finishLayerPropertyGesture(gesture))
        for value in [Double.nan, .infinity, -.infinity] {
            #expect(!model.updateLayerPropertyGesture(gesture, value: value))
        }
        #expect(try snapshot(model) == before)
        #expect(try snapshot(other) == otherBefore)
        #expect(model.finishLayerPropertyGesture(gesture))
        #expect(model.undoStack.isEmpty)
    }

    @Test func nativeTrackingKeepsCapturedCallbacksAcrossReconfiguration() throws {
        let model = try fixture()
        let other = try fixture()
        let slider = ImageEditorLayerPropertyNativeSlider()
        slider.minValue = 0
        slider.maxValue = 1
        slider.step = 0.05
        slider.beginGesture = { model.makeLayerPropertyGestureCallbacks(.opacity) }
        let otherBefore = try snapshot(other)
        slider.trackGesture {
            slider.doubleValue = 0.25
            slider.applyNativeValue()
            let control = ImageEditorLayerPropertyNativeControl(value: 1, range: 0...1, step: 0.05,
                accessibilityTitle: "Fixture opacity", beginGesture: { other.makeLayerPropertyGestureCallbacks(.opacity) })
            control.configure(slider)
            #expect(slider.doubleValue == 0.25)
            slider.doubleValue = 0.5
            slider.applyNativeValue()
            #expect(model.hasActiveLayerPropertyEdit)
        }
        #expect(model.selectedLayerOpacity == 0.5)
        #expect(try snapshot(other) == otherBefore)
        #expect(!model.hasActiveLayerPropertyEdit)
        #expect(slider.trackingCallbacks == nil)
        model.undo()
        #expect(model.selectedLayerOpacity == 1)
        model.redo()
        #expect(model.selectedLayerOpacity == 0.5)
    }

    @Test func nativeTrackingAfterUndoRejectsSubsequentValueAndRelease() throws {
        let model = try fixture()
        let slider = ImageEditorLayerPropertyNativeSlider()
        slider.minValue = 0
        slider.maxValue = 1
        slider.step = 0.05
        slider.beginGesture = { model.makeLayerPropertyGestureCallbacks(.opacity) }
        slider.trackGesture {
            slider.doubleValue = 0.25
            slider.applyNativeValue()
            model.undo()
            slider.doubleValue = 0.5
            slider.applyNativeValue()
        }
        #expect(model.selectedLayerOpacity == 1)
        #expect(model.undoStack.isEmpty && model.redoStack.isEmpty)
        #expect(!model.hasActiveLayerPropertyEdit)
    }

    @Test func nativeKeyboardUsesStepAndIndependentUndo() throws {
        let model = try fixture()
        let slider = ImageEditorLayerPropertyNativeSlider()
        slider.minValue = 0
        slider.maxValue = 1
        slider.step = 0.05
        slider.doubleValue = 1
        slider.beginGesture = { model.makeLayerPropertyGestureCallbacks(.opacity) }
        let left = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: 123))
        slider.keyDown(with: left)
        #expect(abs(model.selectedLayerOpacity - 0.95) < 0.000001)
        slider.keyDown(with: left)
        #expect(abs(model.selectedLayerOpacity - 0.9) < 0.000001)
        #expect(model.undoStack.count == 2)
        model.undo()
        #expect(abs(model.selectedLayerOpacity - 0.95) < 0.000001)
        model.undo()
        #expect(model.selectedLayerOpacity == 1)
        model.redo()
        model.redo()
        #expect(abs(model.selectedLayerOpacity - 0.9) < 0.000001)
    }

    private func fixture() throws -> ImageEditorViewModel {
        let model = try ImageEditorPixelMoveWorkflowFixture.model()
        let index = try #require(model.document.selectedLayerIndex)
        model.document.layers[index].mask = .opaqueMask(size: model.document.canvasSize)
        model.isEditingLayerMask = false
        model.clearUndoHistory()
        return model
    }

    private func value(for property: ImageEditorLayerGestureProperty, next: Bool = false) -> Double {
        switch property {
        case .sourceBlack, .underlyingBlack: next ? 0.3 : 0.2
        case .sourceWhite, .underlyingWhite: next ? 0.7 : 0.8
        case .maskFeather: next ? 4 : 2
        default: next ? 0.5 : 0.6
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
