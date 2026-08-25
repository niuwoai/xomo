//
//  ImageEditorProjectSaveTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/25.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorProjectSaveTests {
    private enum SaveFailure: Error {
        case denied
    }

    @Test func savingToAProjectURLUpdatesItsDestinationWithoutCreatingAnEditTransaction() throws {
        let viewModel = makeViewModel(sourceName: "poster.png")
        let destination = URL(fileURLWithPath: "/tmp/Poster.xomoproject")
        let dataBeforeSave = try viewModel.projectData()
        let historyBeforeSave = viewModel.document.history
        let undoCountBeforeSave = viewModel.undoStack.count
        let redoCountBeforeSave = viewModel.redoStack.count
        var writtenData: Data?
        var writtenURL: URL?
        var recentURL: URL?

        let didSave = viewModel.writeProjectDocument(
            to: destination,
            dataWriter: { data, url in
                writtenData = data
                writtenURL = url
            },
            recentDocumentRegistrar: { recentURL = $0 }
        )

        #expect(didSave)
        #expect(writtenData == dataBeforeSave)
        #expect(writtenURL == destination)
        #expect(viewModel.currentProjectURL == destination.standardizedFileURL)
        #expect(recentURL == destination.standardizedFileURL)
        #expect(viewModel.document.history == historyBeforeSave)
        #expect(viewModel.undoStack.count == undoCountBeforeSave)
        #expect(viewModel.redoStack.count == redoCountBeforeSave)
        #expect(try viewModel.projectData() == dataBeforeSave)
    }

    @Test func failedSaveKeepsThePreviousDestinationAndDoesNotRegisterTheRejectedURL() {
        let viewModel = makeViewModel(sourceName: "poster.png")
        let originalURL = URL(fileURLWithPath: "/tmp/Original.xomoproject")
        let rejectedURL = URL(fileURLWithPath: "/tmp/Rejected.xomoproject")
        var recentURLs: [URL] = []

        let initialSaveSucceeded = viewModel.writeProjectDocument(
            to: originalURL,
            dataWriter: { _, _ in },
            recentDocumentRegistrar: { recentURLs.append($0) }
        )
        #expect(initialSaveSucceeded)
        let projectDataBeforeFailure = try? viewModel.projectData()
        let historyBeforeFailure = viewModel.document.history

        let rejectedSaveSucceeded = viewModel.writeProjectDocument(
            to: rejectedURL,
            dataWriter: { _, _ in throw SaveFailure.denied },
            recentDocumentRegistrar: { recentURLs.append($0) }
        )
        #expect(!rejectedSaveSucceeded)

        #expect(viewModel.currentProjectURL == originalURL.standardizedFileURL)
        #expect(recentURLs == [originalURL.standardizedFileURL])
        #expect((try? viewModel.projectData()) == projectDataBeforeFailure)
        #expect(viewModel.document.history == historyBeforeFailure)
        #expect(
            viewModel.statusText
                == L10n.format(
                    "imageEditor.status.projectSaveFailedWithReason",
                    SaveFailure.denied.localizedDescription
                )
        )
    }

    @Test func nativeProjectOpenSetsTheSaveDestinationAndReplacementDocumentsClearIt() throws {
        let source = makeViewModel(sourceName: "saved.png")
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-save-routing-\(UUID().uuidString).xomoproject")
        try source.projectData().write(to: projectURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let viewModel = makeViewModel(sourceName: "initial.png")
        viewModel.openDocument(at: projectURL, recentDocumentRegistrar: { _ in })
        #expect(viewModel.currentProjectURL == projectURL.standardizedFileURL)

        viewModel.loadExternalImageDocument(
            ImageEditorDocument(
                sourceName: "photo.png",
                image: NSImage.transparent(size: CGSize(width: 9, height: 7))
            )
        )
        #expect(viewModel.currentProjectURL == nil)

        viewModel.openDocument(at: projectURL, recentDocumentRegistrar: { _ in })
        #expect(viewModel.currentProjectURL == projectURL.standardizedFileURL)
        viewModel.createCanvas(from: XomoCanvasDraft(preset: .phonePortrait))
        #expect(viewModel.currentProjectURL == nil)
    }

    @Test func projectRestorationFailurePreservesTheCurrentDocumentAndSaveDestination() throws {
        let viewModel = makeViewModel(sourceName: "current.png")
        let currentURL = URL(fileURLWithPath: "/tmp/Current.xomoproject")
        var recentURLs: [URL] = []
        let currentSaveSucceeded = viewModel.writeProjectDocument(
            to: currentURL,
            dataWriter: { _, _ in },
            recentDocumentRegistrar: { recentURLs.append($0) }
        )
        #expect(currentSaveSucceeded)
        let documentBeforeOpen = try viewModel.projectData()

        var invalidProject = try #require(
            JSONSerialization.jsonObject(with: documentBeforeOpen) as? [String: Any]
        )
        invalidProject["layers"] = []
        let invalidURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-empty-project-\(UUID().uuidString).xomoproject")
        try JSONSerialization.data(withJSONObject: invalidProject).write(
            to: invalidURL,
            options: .atomic
        )
        defer { try? FileManager.default.removeItem(at: invalidURL) }

        viewModel.openDocument(
            at: invalidURL,
            recentDocumentRegistrar: { recentURLs.append($0) }
        )

        #expect(viewModel.currentProjectURL == currentURL.standardizedFileURL)
        #expect(try viewModel.projectData() == documentBeforeOpen)
        #expect(recentURLs == [currentURL.standardizedFileURL])
    }

    @Test func fileMenuWiresSaveAndSaveAsWithClassicShortcutsAndLocalizedTitles() throws {
        let root = Self.repositoryRoot()
        let commands = try String(
            contentsOf: root.appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )
        let menuBar = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let project = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorProjectDocument.swift"),
            encoding: .utf8
        )

        #expect(commands.contains("imageEditor.action.projectSaveAs"))
        #expect(commands.contains(".keyboardShortcut(\"s\", modifiers: [.command, .shift])"))
        #expect(menuBar.contains("saveProject: { viewModel.saveProjectDocument() }"))
        #expect(menuBar.contains("saveProjectAs: { viewModel.saveProjectDocumentAs() }"))
        #expect(project.contains("guard let currentProjectURL else"))
        #expect(project.contains("writeProjectDocument(to: currentProjectURL)"))

        for locale in ["zh-Hans", "en", "ja"] {
            let strings = try String(
                contentsOf: root.appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(strings.contains("\"imageEditor.action.projectSaveAs\" ="))
        }
    }

    private func makeViewModel(sourceName: String) -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: sourceName,
            image: NSImage.transparent(size: CGSize(width: 16, height: 12))
        ) { _ in }
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
