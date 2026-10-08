//
//  ImageEditorProjectRevertTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/25.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorProjectRevertTests {
    private enum ReadFailure: Error {
        case unavailable
    }

    @Test func revertIsUnavailableUntilTheDocumentHasAProjectDestination() throws {
        let viewModel = makeViewModel(sourceName: "untitled.png")
        let dataBefore = try viewModel.projectData()

        #expect(!viewModel.canRevertProjectDocument)
        let didRevert = viewModel.revertProjectDocument()
        #expect(!didRevert)
        #expect(viewModel.currentProjectURL == nil)
        #expect(try viewModel.projectData() == dataBefore)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.projectRevertUnavailable"))
    }

    @Test func revertingReloadsTheSavedProjectAndClearsUnsavedHistoryTransactions() throws {
        let savedViewModel = makeViewModel(sourceName: "saved.png")
        let savedLayerName = try #require(savedViewModel.document.selectedLayer?.name)
        let savedData = try savedViewModel.projectData()
        let projectURL = try writeTemporaryProject(savedData)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let viewModel = makeViewModel(sourceName: "initial.png")
        #expect(viewModel.openProjectDocument(data: savedData, at: projectURL))
        viewModel.renameSelectedLayer(to: "Unsaved Rename")
        #expect(viewModel.document.selectedLayer?.name == "Unsaved Rename")
        #expect(!viewModel.undoStack.isEmpty)

        let didRevert = viewModel.revertProjectDocument()
        #expect(didRevert)

        #expect(viewModel.currentProjectURL == projectURL.standardizedFileURL)
        #expect(viewModel.document.selectedLayer?.name == savedLayerName)
        #expect(viewModel.undoStack.isEmpty)
        #expect(viewModel.redoStack.isEmpty)
        #expect(try viewModel.projectData() == savedData)
        #expect(
            viewModel.statusText
                == L10n.format("imageEditor.status.projectReverted", projectURL.lastPathComponent)
        )
    }

    @Test func revertReadFailurePreservesDocumentDestinationUndoAndRedo() throws {
        let savedData = try makeViewModel(sourceName: "saved.png").projectData()
        let projectURL = try writeTemporaryProject(savedData)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let viewModel = makeViewModel(sourceName: "initial.png")
        #expect(viewModel.openProjectDocument(data: savedData, at: projectURL))
        viewModel.renameSelectedLayer(to: "Changed")
        viewModel.undo()
        let documentBefore = try viewModel.projectData()
        let undoCountBefore = viewModel.undoStack.count
        let redoCountBefore = viewModel.redoStack.count

        let didRevert = viewModel.revertProjectDocument { _ in
            throw ReadFailure.unavailable
        }

        #expect(!didRevert)
        #expect(viewModel.currentProjectURL == projectURL.standardizedFileURL)
        #expect(try viewModel.projectData() == documentBefore)
        #expect(viewModel.undoStack.count == undoCountBefore)
        #expect(viewModel.redoStack.count == redoCountBefore)
        #expect(
            viewModel.statusText
                == L10n.format(
                    "imageEditor.status.projectRevertFailedWithReason",
                    ReadFailure.unavailable.localizedDescription
                )
        )
    }

    @Test func revertRestorationFailureIsAtomic() throws {
        let savedData = try makeViewModel(sourceName: "saved.png").projectData()
        let projectURL = try writeTemporaryProject(savedData)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let viewModel = makeViewModel(sourceName: "initial.png")
        #expect(viewModel.openProjectDocument(data: savedData, at: projectURL))
        viewModel.renameSelectedLayer(to: "Keep This Change")
        let documentBefore = try viewModel.projectData()
        let undoCountBefore = viewModel.undoStack.count

        var emptyProject = try #require(
            JSONSerialization.jsonObject(with: savedData) as? [String: Any]
        )
        emptyProject["layers"] = []
        let invalidData = try JSONSerialization.data(withJSONObject: emptyProject)

        let didRevert = viewModel.revertProjectDocument(dataReader: { _ in invalidData })
        #expect(!didRevert)
        #expect(viewModel.currentProjectURL == projectURL.standardizedFileURL)
        #expect(try viewModel.projectData() == documentBefore)
        #expect(viewModel.undoStack.count == undoCountBefore)
    }

    @Test func fileMenuWiresAConfirmedLocalizedRevertThatRequiresAProjectDestination() throws {
        let root = Self.repositoryRoot()
        let commands = try source("veilpic/XomoApplicationCommands.swift", root: root)
        let menuBar = try source("veilpic/ImageEditorMenuBar.swift", root: root)
        let project = try source("veilpic/ImageEditorProjectDocument.swift", root: root)

        #expect(commands.contains("imageEditor.action.projectRevert"))
        #expect(commands.contains(".disabled(actions?.canRevertProject != true)"))
        #expect(menuBar.contains("revertProject: { viewModel.presentProjectRevertConfirmation() }"))
        #expect(menuBar.contains("canRevertProject: viewModel.canRevertProjectDocument"))
        #expect(project.contains("alert.alertStyle = .warning"))
        #expect(project.contains("imageEditor.confirmation.projectRevertMessage"))
        #expect(project.contains("response == .alertFirstButtonReturn"))

        let keys = [
            "imageEditor.action.projectRevert",
            "imageEditor.action.projectRevertConfirm",
            "imageEditor.status.projectReverted",
            "imageEditor.status.projectRevertUnavailable",
            "imageEditor.status.projectRevertFailedWithReason",
            "imageEditor.confirmation.projectRevertTitle",
            "imageEditor.confirmation.projectRevertMessage",
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

    private func writeTemporaryProject(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-revert-\(UUID().uuidString).xomoproject")
        try data.write(to: url, options: .atomic)
        return url
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
