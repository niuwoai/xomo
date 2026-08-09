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
}
