//
//  ImageEditorQuickExportPNGTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/25.
//

import AppKit
import CoreFoundation
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import musepic

@MainActor
struct ImageEditorQuickExportPNGTests {
    private enum ExportFailure: Error {
        case denied
    }

    @Test func displayP3CompositeQuickExportEncodesSRGBReferencePixels() throws {
        let sourceSpace = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let sourceBytes: [UInt8] = [200, 120, 40, 255]
        let provider = try #require(CGDataProvider(data: Data(sourceBytes) as CFData))
        let source = try #require(CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
            space: sourceSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        let importedImage = NSImage(cgImage: source, size: CGSize(width: 1, height: 1))
        let importedDocument = XomoExternalImageDocumentFactory.make(
            sourceName: "p3.png",
            image: importedImage
        )
        let viewModel = ImageEditorViewModel(
            sourceName: "initial.png",
            image: NSImage.transparent(size: CGSize(width: 1, height: 1))
        ) { _ in }
        viewModel.document = importedDocument

        let pngData = try #require(viewModel.quickExportPNGData())
        let decoded = try #require(NSImage(data: pngData))
        let decodedCGImage = try #require(decoded.cgImage(forProposedRect: nil, context: nil, hints: nil))
        #expect(decodedCGImage.colorSpace?.name == CGColorSpace.sRGB)

        let sourceColor = try #require(CGColor(
            colorSpace: sourceSpace,
            components: [200 / 255, 120 / 255, 40 / 255, 1]
        ))
        let sRGB = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let expectedColor = try #require(sourceColor.converted(
            to: sRGB,
            intent: .relativeColorimetric,
            options: nil
        ))
        let expectedComponents = try #require(expectedColor.components)
        let expected = expectedComponents.prefix(3).map { UInt8(($0 * 255).rounded()) } + [255]
        #expect(imageEditorRGBABytes(decoded, width: 1, height: 1) == expected)
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

    @Test func copyAsPNGUsesOneTimesCompositeWithoutChangingEditorState() throws {
        let viewModel = makeViewModel(sourceName: "Share Card.psd")
        viewModel.renameSelectedLayer(to: "Unsaved Copy")
        viewModel.exportSettings.format = .jpeg
        viewModel.exportSettings.scope = .selectedLayer
        viewModel.exportSettings.scale = 4
        viewModel.exportSettings.batchScales = [2, 3, 4]
        viewModel.exportSettings.namingRule = .sourceAndScope
        let projectDataBeforeCopy = try viewModel.projectData()
        let historyBeforeCopy = viewModel.document.history
        let undoCountBeforeCopy = viewModel.undoStack.count
        let redoCountBeforeCopy = viewModel.redoStack.count
        let settingsBeforeCopy = viewModel.exportSettings
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("xomo-tests.copy-quick-png.\(UUID().uuidString)")
        )
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }

        #expect(viewModel.copyQuickExportPNG(to: pasteboard))

        let pngData = try #require(pasteboard.data(forType: .png))
        #expect(pngData.prefix(8) == Data([137, 80, 78, 71, 13, 10, 26, 10]))
        let image = try #require(NSImage(data: pngData))
        #expect(image.size == CGSize(width: 7, height: 5))
        #expect(viewModel.quickExportPNGFilename() == "Share Card.png")
        #expect(try viewModel.projectData() == projectDataBeforeCopy)
        #expect(viewModel.document.history == historyBeforeCopy)
        #expect(viewModel.undoStack.count == undoCountBeforeCopy)
        #expect(viewModel.redoStack.count == redoCountBeforeCopy)
        #expect(viewModel.exportSettings == settingsBeforeCopy)
        #expect(viewModel.hasUnsavedProjectChanges)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.copyQuickExportPNG"))
    }

    @Test func sharedFileMenuWiresQuickPNGExportInEveryLanguage() throws {
        let root = Self.repositoryRoot()
        let commands = try source("veilpic/XomoApplicationCommands.swift", root: root)
        let menuBar = try source("veilpic/ImageEditorMenuBar.swift", root: root)
        let export = try source("veilpic/ImageEditorExport.swift", root: root)

        #expect(commands.contains("imageEditor.action.quickExportPNG"))
        #expect(commands.contains("actions?.quickExportPNG()"))
        #expect(commands.contains("imageEditor.action.copyQuickExportPNG"))
        #expect(commands.contains("actions?.copyQuickExportPNG()"))
        #expect(menuBar.contains("quickExportPNG: { viewModel.quickExportPNG() }"))
        #expect(menuBar.contains("copyQuickExportPNG: { viewModel.copyQuickExportPNG() }"))
        #expect(export.contains("panel.allowedContentTypes = [.png]"))
        #expect(export.contains("self.writeQuickExportPNG(to: url)"))
        #expect(export.contains("func copyQuickExportPNG(to pasteboard: NSPasteboard = .general)"))

        for locale in ["zh-Hans", "en", "ja"] {
            let strings = try source(
                "veilpic/\(locale).lproj/Localizable.strings",
                root: root
            )
            #expect(strings.contains("\"imageEditor.action.quickExportPNG\" ="))
            #expect(strings.contains("\"imageEditor.action.copyQuickExportPNG\" ="))
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
