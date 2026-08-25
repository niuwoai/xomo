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

    @Test func savingProjectCopyPreservesCurrentIdentityBaselineAndEditTransactions() throws {
        let viewModel = makeViewModel(sourceName: "poster.png")
        let currentURL = URL(fileURLWithPath: "/tmp/Current.xomoproject")
        let copyURL = URL(fileURLWithPath: "/tmp/archive/../Current Copy.xomoproject")
        let didSaveCurrent = viewModel.writeProjectDocument(
            to: currentURL,
            dataWriter: { _, _ in },
            recentDocumentRegistrar: { _ in }
        )
        #expect(didSaveCurrent)
        viewModel.renameSelectedLayer(to: "Unsaved Copy Content")
        let projectDataBeforeCopy = try viewModel.projectData()
        let historyBeforeCopy = viewModel.document.history
        let undoCountBeforeCopy = viewModel.undoStack.count
        let redoCountBeforeCopy = viewModel.redoStack.count
        var copiedData: Data?
        var copiedURL: URL?

        let didSaveCopy = viewModel.writeProjectDocumentCopy(
            to: copyURL,
            dataWriter: { data, url in
                copiedData = data
                copiedURL = url
            }
        )

        #expect(didSaveCopy)
        #expect(copiedData == projectDataBeforeCopy)
        #expect(copiedURL == copyURL.standardizedFileURL)
        #expect(viewModel.currentProjectURL == currentURL.standardizedFileURL)
        #expect(try viewModel.projectData() == projectDataBeforeCopy)
        #expect(viewModel.document.history == historyBeforeCopy)
        #expect(viewModel.undoStack.count == undoCountBeforeCopy)
        #expect(viewModel.redoStack.count == redoCountBeforeCopy)
        #expect(viewModel.hasUnsavedProjectChanges)
        #expect(
            viewModel.statusText
                == L10n.format(
                    "imageEditor.status.projectCopySaved",
                    copyURL.standardizedFileURL.lastPathComponent
                )
        )
    }

    @Test func projectCopyRejectsTheCurrentDestinationBeforeWriting() throws {
        let viewModel = makeViewModel(sourceName: "poster.png")
        let currentURL = URL(fileURLWithPath: "/tmp/Current.xomoproject")
        let didSaveCurrent = viewModel.writeProjectDocument(
            to: currentURL,
            dataWriter: { _, _ in },
            recentDocumentRegistrar: { _ in }
        )
        #expect(didSaveCurrent)
        viewModel.renameSelectedLayer(to: "Still Dirty")
        let projectDataBeforeCopy = try viewModel.projectData()
        let undoCountBeforeCopy = viewModel.undoStack.count
        var writeCount = 0

        let didSaveCopy = viewModel.writeProjectDocumentCopy(
            to: URL(fileURLWithPath: "/tmp/folder/../Current.xomoproject"),
            dataWriter: { _, _ in writeCount += 1 }
        )

        #expect(!didSaveCopy)
        #expect(writeCount == 0)
        #expect(viewModel.currentProjectURL == currentURL.standardizedFileURL)
        #expect(try viewModel.projectData() == projectDataBeforeCopy)
        #expect(viewModel.undoStack.count == undoCountBeforeCopy)
        #expect(viewModel.hasUnsavedProjectChanges)
        #expect(
            viewModel.statusText
                == L10n.text("imageEditor.status.projectCopySameDestination")
        )
    }

    @Test func failedProjectCopyKeepsUnnamedDocumentAndTransactionsIntact() throws {
        let viewModel = makeViewModel(sourceName: "draft.png")
        viewModel.renameSelectedLayer(to: "Unsaved Draft")
        let projectDataBeforeCopy = try viewModel.projectData()
        let historyBeforeCopy = viewModel.document.history
        let undoCountBeforeCopy = viewModel.undoStack.count
        let redoCountBeforeCopy = viewModel.redoStack.count

        let didSaveCopy = viewModel.writeProjectDocumentCopy(
            to: URL(fileURLWithPath: "/tmp/Rejected Copy.xomoproject"),
            dataWriter: { _, _ in throw SaveFailure.denied }
        )

        #expect(!didSaveCopy)
        #expect(viewModel.currentProjectURL == nil)
        #expect(try viewModel.projectData() == projectDataBeforeCopy)
        #expect(viewModel.document.history == historyBeforeCopy)
        #expect(viewModel.undoStack.count == undoCountBeforeCopy)
        #expect(viewModel.redoStack.count == redoCountBeforeCopy)
        #expect(viewModel.hasUnsavedProjectChanges)
        #expect(
            viewModel.statusText
                == L10n.format(
                    "imageEditor.status.projectCopyFailedWithReason",
                    SaveFailure.denied.localizedDescription
                )
        )
    }

    @Test func projectCopyFilenameUsesSourceThenCurrentProjectIdentity() {
        let viewModel = makeViewModel(sourceName: "Poster Draft.png")
        let formatter: (String) -> String = { "\($0) COPY" }

        #expect(
            viewModel.projectCopyFilename(copyNameFormatter: formatter)
                == "Poster Draft COPY.xomoproject"
        )

        let currentURL = URL(fileURLWithPath: "/tmp/Named Project.xomoproject")
        let didSave = viewModel.writeProjectDocument(
            to: currentURL,
            dataWriter: { _, _ in },
            recentDocumentRegistrar: { _ in }
        )
        #expect(didSave)
        #expect(
            viewModel.projectCopyFilename(copyNameFormatter: formatter)
                == "Named Project COPY.xomoproject"
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

    @Test func revealingProjectInFinderUsesOnlyTheSavedURLWithoutCreatingAnEditTransaction() throws {
        let viewModel = makeViewModel(sourceName: "poster.png")
        let destination = URL(fileURLWithPath: "/tmp/Folder/../Poster.xomoproject")
        var revealedURLs: [[URL]] = []

        #expect(!viewModel.canRevealProjectInFinder)
        let didRevealBeforeSave = viewModel.revealProjectInFinder { revealedURLs.append($0) }
        #expect(!didRevealBeforeSave)
        #expect(revealedURLs.isEmpty)

        let didSave = viewModel.writeProjectDocument(
            to: destination,
            dataWriter: { _, _ in },
            recentDocumentRegistrar: { _ in }
        )
        #expect(didSave)
        viewModel.renameSelectedLayer(to: "Dirty Layer")
        let projectDataBeforeReveal = try viewModel.projectData()
        let historyBeforeReveal = viewModel.document.history
        let undoCountBeforeReveal = viewModel.undoStack.count
        let redoCountBeforeReveal = viewModel.redoStack.count
        #expect(viewModel.hasUnsavedProjectChanges)

        #expect(viewModel.canRevealProjectInFinder)
        let didRevealSavedProject = viewModel.revealProjectInFinder { revealedURLs.append($0) }
        #expect(didRevealSavedProject)
        #expect(revealedURLs == [[destination.standardizedFileURL]])
        #expect(try viewModel.projectData() == projectDataBeforeReveal)
        #expect(viewModel.document.history == historyBeforeReveal)
        #expect(viewModel.undoStack.count == undoCountBeforeReveal)
        #expect(viewModel.redoStack.count == redoCountBeforeReveal)
        #expect(viewModel.hasUnsavedProjectChanges)

        viewModel.loadExternalImageDocument(
            ImageEditorDocument(
                sourceName: "replacement.png",
                image: NSImage.transparent(size: CGSize(width: 8, height: 6))
            )
        )
        #expect(!viewModel.canRevealProjectInFinder)
        let didRevealReplacement = viewModel.revealProjectInFinder { revealedURLs.append($0) }
        #expect(!didRevealReplacement)
        #expect(revealedURLs.count == 1)
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
        #expect(commands.contains("imageEditor.action.projectSaveCopy"))
        #expect(commands.contains(".keyboardShortcut(\"s\", modifiers: [.command, .option])"))
        #expect(menuBar.contains("saveProject: { viewModel.saveProjectDocument() }"))
        #expect(menuBar.contains("saveProjectAs: { viewModel.saveProjectDocumentAs() }"))
        #expect(menuBar.contains("saveProjectCopy: { viewModel.saveProjectDocumentCopy() }"))
        #expect(commands.contains("actions?.saveProjectCopy()"))
        #expect(menuBar.contains("revealProjectInFinder: { viewModel.revealProjectInFinder() }"))
        #expect(commands.contains("actions?.revealProjectInFinder()"))
        #expect(commands.contains("actions?.canRevealProjectInFinder != true"))
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
            #expect(strings.contains("\"imageEditor.action.projectSaveCopy\" ="))
            #expect(strings.contains("\"imageEditor.status.projectCopySaved\" ="))
            #expect(strings.contains("\"imageEditor.status.projectCopySameDestination\" ="))
            #expect(strings.contains("\"imageEditor.status.projectCopyFailedWithReason\" ="))
            #expect(strings.contains("\"imageEditor.project.copyFilename\" ="))
            #expect(strings.contains("\"imageEditor.action.projectRevealInFinder\" ="))
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
