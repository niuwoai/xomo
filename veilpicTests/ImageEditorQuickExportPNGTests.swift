//
//  ImageEditorQuickExportPNGTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/25.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorQuickExportPNGTests {
    private enum ExportFailure: Error {
        case denied
    }

    @Test func quickExportWritesOneTimesCompositePNGWithoutChangingEditorState() throws {
        let viewModel = makeViewModel(sourceName: "Poster Draft.jpg")
        let projectURL = URL(fileURLWithPath: "/tmp/Poster Project.xomoproject")
        let didSaveProject = viewModel.writeProjectDocument(
            to: projectURL,
            dataWriter: { _, _ in },
            recentDocumentRegistrar: { _ in }
        )
        #expect(didSaveProject)
        viewModel.renameSelectedLayer(to: "Unsaved Layer")
        viewModel.exportSettings.format = .jpeg
        viewModel.exportSettings.scope = .selectedLayer
        viewModel.exportSettings.scale = 3
        viewModel.exportSettings.batchScales = [2, 3]
        viewModel.exportSettings.namingRule = .sourceAndScope
        viewModel.exportSettings.quality = 0.2

        let projectDataBeforeExport = try viewModel.projectData()
        let historyBeforeExport = viewModel.document.history
        let undoCountBeforeExport = viewModel.undoStack.count
        let redoCountBeforeExport = viewModel.redoStack.count
        let settingsBeforeExport = viewModel.exportSettings
        var writtenData: Data?
        var writtenURL: URL?
        let destination = URL(fileURLWithPath: "/tmp/output/../Poster.png")

        let didExport = viewModel.writeQuickExportPNG(
            to: destination,
            dataWriter: { data, url in
                writtenData = data
                writtenURL = url
            }
        )

        #expect(didExport)
        let pngData = try #require(writtenData)
        #expect(pngData.prefix(8) == Data([137, 80, 78, 71, 13, 10, 26, 10]))
        let decoded = try #require(NSImage(data: pngData))
        #expect(decoded.size == CGSize(width: 7, height: 5))
        #expect(writtenURL == destination.standardizedFileURL)
        #expect(viewModel.quickExportPNGFilename() == "Poster Draft.png")
        #expect(viewModel.currentProjectURL == projectURL.standardizedFileURL)
        #expect(try viewModel.projectData() == projectDataBeforeExport)
        #expect(viewModel.document.history == historyBeforeExport)
        #expect(viewModel.undoStack.count == undoCountBeforeExport)
        #expect(viewModel.redoStack.count == redoCountBeforeExport)
        #expect(viewModel.exportSettings == settingsBeforeExport)
        #expect(viewModel.hasUnsavedProjectChanges)
        #expect(
            viewModel.statusText
                == L10n.format("imageEditor.status.exported", "Poster.png")
        )
    }

    @Test func failedQuickExportPreservesProjectAndExportSettings() throws {
        let viewModel = makeViewModel(sourceName: "Draft.png")
        viewModel.renameSelectedLayer(to: "Dirty")
        viewModel.exportSettings.format = .webp
        viewModel.exportSettings.scope = .selection
        viewModel.exportSettings.scale = 2
        viewModel.exportSettings.batchScales = [3]
        let projectDataBeforeExport = try viewModel.projectData()
        let historyBeforeExport = viewModel.document.history
        let undoCountBeforeExport = viewModel.undoStack.count
        let redoCountBeforeExport = viewModel.redoStack.count
        let settingsBeforeExport = viewModel.exportSettings

        let didExport = viewModel.writeQuickExportPNG(
            to: URL(fileURLWithPath: "/tmp/Rejected.png"),
            dataWriter: { _, _ in throw ExportFailure.denied }
        )

        #expect(!didExport)
        #expect(viewModel.currentProjectURL == nil)
        #expect(try viewModel.projectData() == projectDataBeforeExport)
        #expect(viewModel.document.history == historyBeforeExport)
        #expect(viewModel.undoStack.count == undoCountBeforeExport)
        #expect(viewModel.redoStack.count == redoCountBeforeExport)
        #expect(viewModel.exportSettings == settingsBeforeExport)
        #expect(viewModel.hasUnsavedProjectChanges)
        #expect(
            viewModel.statusText
                == L10n.format(
                    "imageEditor.status.exportFailedWithReason",
                    ExportFailure.denied.localizedDescription
                )
        )
    }

    @Test func sharedFileMenuWiresQuickPNGExportInEveryLanguage() throws {
        let root = Self.repositoryRoot()
        let commands = try source("veilpic/XomoApplicationCommands.swift", root: root)
        let menuBar = try source("veilpic/ImageEditorMenuBar.swift", root: root)
        let export = try source("veilpic/ImageEditorExport.swift", root: root)

        #expect(commands.contains("imageEditor.action.quickExportPNG"))
        #expect(commands.contains("actions?.quickExportPNG()"))
        #expect(menuBar.contains("quickExportPNG: { viewModel.quickExportPNG() }"))
        #expect(export.contains("panel.allowedContentTypes = [.png]"))
        #expect(export.contains("self.writeQuickExportPNG(to: url)"))

        for locale in ["zh-Hans", "en", "ja"] {
            let strings = try source(
                "veilpic/\(locale).lproj/Localizable.strings",
                root: root
            )
            #expect(strings.contains("\"imageEditor.action.quickExportPNG\" ="))
        }
    }

    private func makeViewModel(sourceName: String) -> ImageEditorViewModel {
        let image = NSImage.rendered(size: CGSize(width: 7, height: 5)) { rect in
            NSColor.systemRed.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: CGSize(width: 7, height: 5))
        return ImageEditorViewModel(sourceName: sourceName, image: image) { _ in }
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
