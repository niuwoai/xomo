import Foundation
import Testing
@testable import musepic

struct ImageEditorTextEditingLifecycleTests {
    @Test
    func escapeCancelsCanvasTextEditingWhileContextChangesCommitIt() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        let overlayStart = try #require(source.range(of: "private func canvasTextEditingOverlay"))
        let beginStart = try #require(
            source[overlayStart.upperBound...].range(of: "private func beginCanvasTextEditing")
        )
        let overlaySource = source[overlayStart.lowerBound..<beginStart.lowerBound]
        #expect(overlaySource.contains(".onExitCommand"))
        #expect(overlaySource.contains("cancelCanvasTextEditing()"))

        let toolChangeStart = try #require(source.range(of: ".onChange(of: viewModel.selectedTool)"))
        let selectionChangeStart = try #require(
            source[toolChangeStart.upperBound...].range(of: ".onChange(of: viewModel.document.selectedLayerIDs)")
        )
        let contextChangeSource = source[toolChangeStart.lowerBound..<selectionChangeStart.lowerBound]
        #expect(contextChangeSource.contains("if tool != .text"))
        #expect(contextChangeSource.contains("if tab == .components"))
        #expect(contextChangeSource.components(separatedBy: "commitCanvasTextEditingIfNeeded()").count == 3)
        #expect(!contextChangeSource.contains("cancelCanvasTextEditing()"))
    }

    @Test
    func conditionalCommitCannotCreateTextWithoutAnActiveCanvasEditor() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let helperStart = try #require(source.range(of: "private func commitCanvasTextEditingIfNeeded()"))
        let cancelStart = try #require(
            source[helperStart.upperBound...].range(of: "private func cancelCanvasTextEditing()")
        )
        let helperSource = source[helperStart.lowerBound..<cancelStart.lowerBound]

        #expect(helperSource.contains("guard canvasTextEditingOrigin != nil else { return }"))
        #expect(helperSource.contains("commitCanvasTextEditing()"))
    }

    @Test
    func commandReturnCommitsWithoutMakingOverlayButtonsFocusable() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let overlayStart = try #require(source.range(of: "private func canvasTextEditingOverlay"))
        let beginStart = try #require(
            source[overlayStart.upperBound...].range(of: "private func beginCanvasTextEditing")
        )
        let overlaySource = source[overlayStart.lowerBound..<beginStart.lowerBound]

        #expect(overlaySource.contains("Button { commitCanvasTextEditing() }"))
        #expect(overlaySource.contains(".keyboardShortcut(.return, modifiers: [.command])"))
        #expect(overlaySource.components(separatedBy: ".focusable(false)").count == 3)
        #expect(!overlaySource.contains(".keyboardShortcut(.return, modifiers: [])"))
    }

    @Test
    func moveToolDoubleClickRoutesForegroundTargetsIntoSelectionOrTextEditing() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let bridgeSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "veilpic/ImageEditorScrollZoom.swift"
            ),
            encoding: .utf8
        )

        #expect(bridgeSource.contains("objectMoveCandidateClickCount = event.clickCount"))
        #expect(
            bridgeSource.contains(
                "onObjectMoveCandidateBegan?(location, flags, event.clickCount)"
            )
        )
        #expect(
            bridgeSource.contains(
                "objectMoveCandidateModifierFlags,\n                    objectMoveCandidateClickCount"
            )
        )

        let candidateStart = try #require(
            viewSource.range(of: "onObjectMoveCandidateBegan: { location, modifierFlags, clickCount in")
        )
        let activationStart = try #require(
            viewSource[candidateStart.upperBound...].range(of: "onObjectMoveActivated:")
        )
        let candidateSource = viewSource[candidateStart.lowerBound..<activationStart.lowerBound]
        #expect(candidateSource.contains("ImageEditorMoveToolDoubleClickPolicy"))
        #expect(candidateSource.contains("viewModel.moveToolDoubleClickTarget("))
        #expect(candidateSource.contains("canvasTextHitTolerance(in: geometry.size)"))

        let clickStart = try #require(
            viewSource.range(of: "onObjectMoveClicked: { location, modifierFlags, clickCount in")
        )
        let changedStart = try #require(
            viewSource[clickStart.upperBound...].range(of: "onObjectMoveChanged:")
        )
        let clickSource = viewSource[clickStart.lowerBound..<changedStart.lowerBound]
        let targetCall = try #require(
            clickSource.range(of: "viewModel.selectMoveToolDoubleClickTarget(")
        )
        let editCall = try #require(clickSource.range(of: "beginEditingSelectedCanvasTextLayer()"))
        let fallbackCall = try #require(
            clickSource.range(of: "viewModel.selectMovableCanvasTarget(")
        )
        #expect(targetCall.lowerBound < editCall.lowerBound)
        #expect(editCall.lowerBound < fallbackCall.lowerBound)
        #expect(clickSource.contains("if case .editableText = target"))
        #expect(clickSource.contains("return"))

        let helperStart = try #require(
            viewSource.range(of: "private func beginExistingCanvasTextEditing(")
        )
        let commitStart = try #require(
            viewSource[helperStart.upperBound...].range(of: "private func commitCanvasTextEditing()")
        )
        let helperSource = viewSource[helperStart.lowerBound..<commitStart.lowerBound]
        #expect(helperSource.contains("viewModel.selectEditableTextLayer("))
        #expect(helperSource.contains("private func beginEditingSelectedCanvasTextLayer()"))
        #expect(helperSource.contains("layer.isText"))
        #expect(helperSource.contains("!viewModel.document.isEffectivelyPixelsLocked(layer)"))
        #expect(helperSource.contains("canvasTextEditingLayerID = layer.id"))
        #expect(helperSource.contains("isCanvasTextEditorFocused = true"))
        #expect(!helperSource.contains("viewModel.addText("))
    }
}
