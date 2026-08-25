//
//  ImageEditorCopyAsSVGTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/25.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorCopyAsSVGTests {
    @Test func selectedVectorGroupCopiesTightEditableSVGWithoutChangingEditorState() throws {
        let canvasSize = CGSize(width: 160, height: 100)
        let viewModel = ImageEditorViewModel(
            sourceName: "Icon Board.xomoproject",
            image: solidImage(color: .systemRed, size: canvasSize)
        ) { _ in }
        let rasterLayer = try #require(viewModel.document.selectedLayer)
        var group = ImageEditorLayer.group(name: "Selected Group", size: canvasSize)
        group.isGroupExpanded = true
        var selectedShape = ImageEditorLayer.shape(
            name: "Selected Icon",
            frame: CGRect(x: 20, y: 30, width: 40, height: 24),
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: .systemBlue,
                fillOpacity: 1,
                strokeColor: .white,
                strokeWidth: 0,
                strokeOpacity: 1
            )
        )
        selectedShape.groupID = group.id
        let outsideShape = ImageEditorLayer.shape(
            name: "Outside Icon",
            frame: CGRect(x: 90, y: 12, width: 30, height: 18),
            content: ImageEditorShapeContent(
                kind: .ellipse,
                fillColor: .systemGreen,
                fillOpacity: 1,
                strokeColor: .clear,
                strokeWidth: 0,
                strokeOpacity: 0
            )
        )
        viewModel.document.layers = [selectedShape, group, outsideShape, rasterLayer]
        viewModel.document.selectedLayerID = group.id
        viewModel.document.selectedLayerIDs = [group.id]
        viewModel.exportSettings.format = .jpeg
        viewModel.exportSettings.scope = .selectedLayer
        viewModel.exportSettings.scale = 4

        let projectDataBeforeCopy = try viewModel.projectData()
        let historyBeforeCopy = viewModel.document.history
        let undoCountBeforeCopy = viewModel.undoStack.count
        let redoCountBeforeCopy = viewModel.redoStack.count
        let exportSettingsBeforeCopy = viewModel.exportSettings
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("xomo-tests.copy-selected-svg.\(UUID().uuidString)")
        )
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }

        #expect(viewModel.canCopySelectedLayersAsSVG)
        #expect(viewModel.copySelectedLayersAsSVG(to: pasteboard))

        let svgData = try #require(
            pasteboard.data(forType: ClipboardImageWriter.svgPasteboardType)
        )
        let source = try #require(String(data: svgData, encoding: .utf8))
        #expect(pasteboard.string(forType: .string) == source)
        #expect(source.contains("Selected Group"))
        #expect(source.contains("Selected Icon"))
        #expect(!source.contains("Outside Icon"))
        #expect(!source.contains("<image"))
        let xml = try XMLDocument(data: svgData, options: [])
        let root = try #require(xml.rootElement())
        #expect(root.attribute(forName: "width")?.stringValue == "40")
        #expect(root.attribute(forName: "height")?.stringValue == "24")
        #expect(root.attribute(forName: "viewBox")?.stringValue == "20 30 40 24")

        let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: nil
        ) as? [URL]
        let fileURL = try #require(fileURLs?.first)
        #expect(fileURL.lastPathComponent == "Icon-Board-selected.svg")
        #expect(try Data(contentsOf: fileURL) == svgData)

        #expect(try viewModel.projectData() == projectDataBeforeCopy)
        #expect(viewModel.document.history == historyBeforeCopy)
        #expect(viewModel.undoStack.count == undoCountBeforeCopy)
        #expect(viewModel.redoStack.count == redoCountBeforeCopy)
        #expect(viewModel.exportSettings == exportSettingsBeforeCopy)
        #expect(
            viewModel.statusText
                == L10n.text("imageEditor.status.copySelectedLayersAsSVG")
        )
    }

    @Test func rasterOrMissingSelectionIsRejectedWithoutClearingClipboard() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "Raster.png",
            image: solidImage(color: .systemOrange, size: CGSize(width: 24, height: 18))
        ) { _ in }
        let rasterID = try #require(viewModel.document.selectedLayerID)
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("xomo-tests.reject-selected-svg.\(UUID().uuidString)")
        )
        pasteboard.clearContents()
        pasteboard.setString("sentinel", forType: .string)
        defer { pasteboard.clearContents() }

        #expect(!viewModel.canCopySelectedLayersAsSVG)
        #expect(!viewModel.copySelectedLayersAsSVG(to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "sentinel")
        #expect(
            viewModel.statusText
                == L10n.text("imageEditor.status.copySelectedLayersAsSVGFailed")
        )

        viewModel.document.selectedLayerID = nil
        viewModel.document.selectedLayerIDs = []
        #expect(!viewModel.canCopySelectedLayersAsSVG)
        #expect(viewModel.document.layers.contains { $0.id == rasterID })
    }

    @Test func sharedEditMenuWiresCopySelectedSVGInEveryLanguage() throws {
        let root = Self.repositoryRoot()
        let commands = try source("veilpic/XomoApplicationCommands.swift", root: root)
        let menuBar = try source("veilpic/ImageEditorMenuBar.swift", root: root)
        let exporter = try source("veilpic/ImageEditorExport.swift", root: root)

        #expect(commands.contains("imageEditor.action.copySelectedLayersAsSVG"))
        #expect(commands.contains("actions?.copySelectedLayersAsSVG()"))
        #expect(commands.contains("actions?.canCopySelectedLayersAsSVG != true"))
        #expect(
            menuBar.contains(
                "copySelectedLayersAsSVG: { viewModel.copySelectedLayersAsSVG() }"
            )
        )
        #expect(
            menuBar.contains(
                "canCopySelectedLayersAsSVG: viewModel.canCopySelectedLayersAsSVG"
            )
        )
        #expect(exporter.contains("func selectedLayersSVGData() -> Data?"))

        for locale in ["zh-Hans", "en", "ja"] {
            let strings = try source(
                "veilpic/\(locale).lproj/Localizable.strings",
                root: root
            )
            #expect(strings.contains("\"imageEditor.action.copySelectedLayersAsSVG\" ="))
            #expect(strings.contains("\"imageEditor.status.copySelectedLayersAsSVG\" ="))
            #expect(strings.contains("\"imageEditor.status.copySelectedLayersAsSVGFailed\" ="))
        }
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, root: URL) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private func solidImage(color: NSColor, size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            color.setFill()
            rect.fill()
            return true
        }
    }
}
