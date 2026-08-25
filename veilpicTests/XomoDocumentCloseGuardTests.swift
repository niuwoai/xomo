//
//  XomoDocumentCloseGuardTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/25.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct XomoDocumentCloseGuardTests {
    private final class WindowDelegateSpy: NSObject, NSWindowDelegate {
        var allowsClose = true

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            allowsClose
        }
    }

    private enum SaveFailure: Error {
        case denied
    }

    @Test func closeGateConfirmsDirtyDocumentsAndConsumesOnlyOneApproval() {
        var gate = XomoDocumentCloseGate()

        #expect(gate.action(hasUnsavedChanges: false) == .allow)
        #expect(gate.action(hasUnsavedChanges: true) == .requestConfirmation)
        gate.approveNextClose()
        #expect(gate.allowsNextClose)
        #expect(gate.action(hasUnsavedChanges: true) == .allow)
        #expect(!gate.allowsNextClose)
        #expect(gate.action(hasUnsavedChanges: true) == .requestConfirmation)
        gate.approveNextClose()
        gate.cancelPendingApproval()
        #expect(gate.action(hasUnsavedChanges: true) == .requestConfirmation)
    }

    @Test func undoingBackToTheBaselineClearsTheUnsavedStateExactly() {
        let viewModel = makeViewModel(sourceName: "clean.png")

        #expect(!viewModel.hasUnsavedProjectChanges)
        viewModel.renameSelectedLayer(to: "Changed")
        #expect(viewModel.hasUnsavedProjectChanges)
        viewModel.undo()
        #expect(!viewModel.hasUnsavedProjectChanges)
        viewModel.redo()
        #expect(viewModel.hasUnsavedProjectChanges)
    }

    @Test func successfulSaveAdvancesTheBaselineWhileFailedSaveKeepsTheDocumentDirty() {
        let viewModel = makeViewModel(sourceName: "poster.png")
        let destination = URL(fileURLWithPath: "/tmp/Close-Guard.xomoproject")

        let initialSave = viewModel.writeProjectDocument(
            to: destination,
            dataWriter: { _, _ in },
            recentDocumentRegistrar: { _ in }
        )
        #expect(initialSave)
        #expect(!viewModel.hasUnsavedProjectChanges)

        viewModel.renameSelectedLayer(to: "Dirty")
        #expect(viewModel.hasUnsavedProjectChanges)
        let failedSave = viewModel.writeProjectDocument(
            to: destination,
            dataWriter: { _, _ in throw SaveFailure.denied },
            recentDocumentRegistrar: { _ in }
        )
        #expect(!failedSave)
        #expect(viewModel.hasUnsavedProjectChanges)

        let successfulSave = viewModel.writeProjectDocument(
            to: destination,
            dataWriter: { _, _ in },
            recentDocumentRegistrar: { _ in }
        )
        #expect(successfulSave)
        #expect(!viewModel.hasUnsavedProjectChanges)
    }

    @Test func replacementDocumentsBecomeCleanBaselinesUntilTheirFirstEdit() {
        let viewModel = makeViewModel(sourceName: "initial.png")
        viewModel.renameSelectedLayer(to: "Old Dirty State")
        #expect(viewModel.hasUnsavedProjectChanges)

        viewModel.createCanvas(from: XomoCanvasDraft(preset: .phonePortrait))
        #expect(!viewModel.hasUnsavedProjectChanges)
        viewModel.renameSelectedLayer(to: "Canvas Edit")
        #expect(viewModel.hasUnsavedProjectChanges)

        viewModel.loadExternalImageDocument(
            ImageEditorDocument(
                sourceName: "photo.png",
                image: NSImage.transparent(size: CGSize(width: 20, height: 14))
            )
        )
        #expect(!viewModel.hasUnsavedProjectChanges)
    }

    @Test func windowCoordinatorPreservesThePreviousDelegateVetoAndRestoresItOnDismantle() {
        let viewModel = makeViewModel(sourceName: "clean.png")
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: 120),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let previousDelegate = WindowDelegateSpy()
        window.delegate = previousDelegate
        let coordinator = XomoDocumentCloseGuardCoordinator(viewModel: viewModel)

        coordinator.install(on: window)
        #expect(window.delegate === coordinator)
        previousDelegate.allowsClose = false
        #expect(!coordinator.windowShouldClose(window))
        previousDelegate.allowsClose = true
        #expect(coordinator.windowShouldClose(window))

        coordinator.uninstall()
        #expect(window.delegate === previousDelegate)
    }

    @Test func windowCoordinatorSynchronizesNativeDocumentIdentityAndRestoresHostMetadata() async {
        let viewModel = makeViewModel(sourceName: "poster.png")
        let window = makeWindow()
        let hostURL = URL(fileURLWithPath: "/tmp/Host.xomoproject")
        window.title = "Host Window"
        window.representedURL = hostURL
        window.isDocumentEdited = true
        let coordinator = XomoDocumentCloseGuardCoordinator(viewModel: viewModel)

        coordinator.install(on: window)
        #expect(window.title == "poster.png")
        #expect(window.representedURL == nil)
        #expect(!window.isDocumentEdited)

        viewModel.renameSelectedLayer(to: "Changed")
        await drainMainQueue()
        #expect(window.isDocumentEdited)

        let projectURL = URL(fileURLWithPath: "/tmp/Poster Project.xomoproject")
        let didSave = viewModel.writeProjectDocument(
            to: projectURL,
            dataWriter: { _, _ in },
            recentDocumentRegistrar: { _ in }
        )
        #expect(didSave)
        await drainMainQueue()
        #expect(window.title == projectURL.lastPathComponent)
        #expect(window.representedURL == projectURL.standardizedFileURL)
        #expect(!window.isDocumentEdited)

        viewModel.renameSelectedLayer(to: "Changed Again")
        await drainMainQueue()
        #expect(window.isDocumentEdited)
        viewModel.undo()
        await drainMainQueue()
        #expect(!window.isDocumentEdited)

        viewModel.loadExternalImageDocument(
            ImageEditorDocument(
                sourceName: "photo.png",
                image: NSImage.transparent(size: CGSize(width: 20, height: 14))
            )
        )
        await drainMainQueue()
        #expect(window.title == "photo.png")
        #expect(window.representedURL == nil)
        #expect(!window.isDocumentEdited)

        coordinator.uninstall()
        #expect(window.title == "Host Window")
        #expect(window.representedURL == hostURL)
        #expect(window.isDocumentEdited)
    }

    @Test func cleanApplicationTerminationDoesNotDeferOrPresentConfirmation() {
        let clean = makeViewModel(sourceName: "clean.png")
        let candidate = XomoDocumentTerminationCandidate(
            window: makeWindow(),
            viewModel: clean
        )
        var presentationCount = 0
        var replies: [Bool] = []
        let coordinator = XomoApplicationTerminationCoordinator(
            candidateProvider: { [candidate] },
            confirmationPresenter: { _, _ in presentationCount += 1 }
        )

        let result = coordinator.requestTermination { replies.append($0) }

        #expect(result == .terminateNow)
        #expect(presentationCount == 0)
        #expect(replies.isEmpty)
    }

    @Test func applicationTerminationConfirmsDirtyWindowsSequentiallyAndIgnoresDuplicateRequests() {
        let first = makeDirtyCandidate(sourceName: "first.png")
        let second = makeDirtyCandidate(sourceName: "second.png")
        var presentedNames: [String] = []
        var confirmations: [(@MainActor (Bool) -> Void)] = []
        var replies: [Bool] = []
        let coordinator = XomoApplicationTerminationCoordinator(
            candidateProvider: { [first, second] },
            confirmationPresenter: { candidate, completion in
                presentedNames.append(candidate.viewModel.document.sourceName)
                confirmations.append(completion)
            }
        )

        #expect(coordinator.requestTermination { replies.append($0) } == .terminateLater)
        #expect(presentedNames == ["first.png"])
        #expect(coordinator.requestTermination { _ in
            Issue.record("重复退出请求不应替换原回调")
        } == .terminateLater)
        #expect(presentedNames == ["first.png"])

        confirmations[0](true)
        #expect(presentedNames == ["first.png", "second.png"])
        #expect(replies.isEmpty)
        confirmations[1](true)
        #expect(replies == [true])
    }

    @Test func cancellingAnyDirtyWindowAbortsApplicationTermination() {
        let first = makeDirtyCandidate(sourceName: "first.png")
        let second = makeDirtyCandidate(sourceName: "second.png")
        var presentedNames: [String] = []
        var confirmations: [(@MainActor (Bool) -> Void)] = []
        var replies: [Bool] = []
        let coordinator = XomoApplicationTerminationCoordinator(
            candidateProvider: { [first, second] },
            confirmationPresenter: { candidate, completion in
                presentedNames.append(candidate.viewModel.document.sourceName)
                confirmations.append(completion)
            }
        )

        #expect(coordinator.requestTermination { replies.append($0) } == .terminateLater)
        confirmations[0](false)

        #expect(presentedNames == ["first.png"])
        #expect(replies == [false])
    }

    @Test func windowRegistryTracksInstallUpdateAndUninstall() {
        let registry = XomoDocumentWindowRegistry.shared
        registry.resetForTesting()
        defer { registry.resetForTesting() }
        let first = makeViewModel(sourceName: "first.png")
        let second = makeViewModel(sourceName: "second.png")
        let window = makeWindow()
        let coordinator = XomoDocumentCloseGuardCoordinator(viewModel: first)

        coordinator.install(on: window)
        #expect(registry.terminationCandidates.map(\.viewModel.document.sourceName) == ["first.png"])
        #expect(registry.window(for: first) === window)
        coordinator.viewModel = second
        #expect(registry.terminationCandidates.map(\.viewModel.document.sourceName) == ["second.png"])
        #expect(registry.window(for: first) == nil)
        #expect(registry.window(for: second) === window)
        coordinator.uninstall()
        #expect(registry.terminationCandidates.isEmpty)
    }

    @Test func cleanDocumentReplacementRunsImmediatelyWithoutConfirmation() {
        let viewModel = makeViewModel(sourceName: "clean.png")
        var replacementCount = 0
        var presentationCount = 0
        let coordinator = XomoDocumentReplacementCoordinator(
            windowProvider: { _ in nil },
            confirmationPresenter: { _, _, _ in presentationCount += 1 }
        )

        let result = coordinator.requestReplacement(for: viewModel) {
            replacementCount += 1
        }

        #expect(result == .performed)
        #expect(replacementCount == 1)
        #expect(presentationCount == 0)
    }

    @Test func dirtyDocumentReplacementWaitsForApprovalAndRejectsDuplicateRequests() {
        let viewModel = makeViewModel(sourceName: "dirty.png")
        viewModel.renameSelectedLayer(to: "Dirty")
        let window = makeWindow()
        var confirmation: (@MainActor (Bool) -> Void)?
        var replacementCount = 0
        let coordinator = XomoDocumentReplacementCoordinator(
            windowProvider: { candidate in candidate === viewModel ? window : nil },
            confirmationPresenter: { presentedWindow, candidate, completion in
                #expect(presentedWindow === window)
                #expect(candidate === viewModel)
                confirmation = completion
            }
        )

        #expect(
            coordinator.requestReplacement(for: viewModel) {
                replacementCount += 1
            } == .confirmationPresented
        )
        #expect(
            coordinator.requestReplacement(for: viewModel) {
                Issue.record("等待确认时不应接受第二个替换动作")
            } == .blocked
        )
        #expect(replacementCount == 0)
        confirmation?(false)
        #expect(replacementCount == 0)

        #expect(
            coordinator.requestReplacement(for: viewModel) {
                replacementCount += 1
            } == .confirmationPresented
        )
        confirmation?(true)
        #expect(replacementCount == 1)
    }

    @Test func dirtyDocumentReplacementWithoutAnOwningWindowFailsClosed() {
        let viewModel = makeViewModel(sourceName: "detached.png")
        viewModel.renameSelectedLayer(to: "Dirty")
        var replacementCount = 0
        let coordinator = XomoDocumentReplacementCoordinator(
            windowProvider: { _ in nil },
            confirmationPresenter: { _, _, _ in
                Issue.record("没有所属窗口时不能伪造确认")
            }
        )

        let result = coordinator.requestReplacement(for: viewModel) {
            replacementCount += 1
        }

        #expect(result == .blocked)
        #expect(replacementCount == 0)
    }

    @Test func workspaceAndAllExplicitCloseButtonsUseTheWindowGuardWithLocalizedChoices() throws {
        let root = Self.repositoryRoot()
        let guardSource = try source("veilpic/XomoDocumentCloseGuard.swift", root: root)
        let workspace = try source("veilpic/XomoEditorWorkspaceView.swift", root: root)
        let editor = try source("veilpic/ImageEditorView.swift", root: root)
        let menuBar = try source("veilpic/ImageEditorMenuBar.swift", root: root)
        let project = try source("veilpic/ImageEditorProjectDocument.swift", root: root)
        let externalOpen = try source("veilpic/XomoExternalDocumentOpen.swift", root: root)

        #expect(workspace.contains("XomoDocumentCloseGuard(viewModel: viewModel)"))
        #expect(editor.contains("keyWindow?.performClose(nil)"))
        #expect(!editor.contains("keyWindow?.close()"))
        #expect(menuBar.contains("cancel: { closeWindow() }"))
        #expect(menuBar.contains("viewModel.applyAndClose"))
        #expect(guardSource.contains("func windowShouldClose(_ sender: NSWindow) -> Bool"))
        #expect(guardSource.contains("viewModel.hasUnsavedProjectChanges"))
        #expect(guardSource.contains("Publishers.MergeMany(publishers)"))
        #expect(guardSource.contains("window.representedURL = representedURL"))
        #expect(guardSource.contains("window.isDocumentEdited = isDocumentEdited"))
        #expect(guardSource.contains("viewModel.saveProjectDocument(completion: completion)"))
        #expect(guardSource.contains("case .alertSecondButtonReturn:"))
        #expect(guardSource.contains("gate.approveNextClose()"))
        #expect(project.contains("completion?(false)"))

        let app = try source("veilpic/veilpicApp.swift", root: root)
        #expect(app.contains("func applicationShouldTerminate(_ sender: NSApplication)"))
        #expect(app.contains("terminationCoordinator.requestTermination"))
        #expect(app.contains("reply(toApplicationShouldTerminate: shouldTerminate)"))
        #expect(guardSource.contains("XomoDocumentWindowRegistry.shared.register"))
        #expect(guardSource.contains("XomoDocumentWindowRegistry.shared.unregister"))
        #expect(menuBar.contains("requestDocumentReplacement"))
        #expect(menuBar.contains("openProjectDocumentSafely()"))
        #expect(menuBar.contains("openRecentDocumentSafely(at:"))
        #expect(menuBar.contains("viewModel.createCanvasFromClipboard()"))
        #expect(project.contains("requestProjectReplacement"))
        #expect(externalOpen.contains("XomoDocumentReplacementCoordinator.shared.requestReplacement"))

        let keys = [
            "imageEditor.action.closeSave",
            "imageEditor.action.closeDiscard",
            "imageEditor.confirmation.unsavedCloseTitle",
            "imageEditor.confirmation.unsavedReplaceTitle",
            "imageEditor.confirmation.unsavedCloseMessage",
        ]
        for locale in ["zh-Hans", "en", "ja"] {
            let strings = try source(
                "veilpic/\(locale).lproj/Localizable.strings",
                root: root
            )
            for key in keys {
                #expect(strings.contains("\"\(key)\" ="))
            }
        }
    }

    private func makeViewModel(sourceName: String) -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: sourceName,
            image: NSImage.transparent(size: CGSize(width: 18, height: 12))
        ) { _ in }
    }

    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: 120),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
    }

    private func makeDirtyCandidate(sourceName: String) -> XomoDocumentTerminationCandidate {
        let viewModel = makeViewModel(sourceName: sourceName)
        viewModel.renameSelectedLayer(to: "Dirty \(sourceName)")
        return XomoDocumentTerminationCandidate(
            window: makeWindow(),
            viewModel: viewModel
        )
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }

    private func source(_ relativePath: String, root: URL) throws -> String {
        try String(
            contentsOf: root.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
