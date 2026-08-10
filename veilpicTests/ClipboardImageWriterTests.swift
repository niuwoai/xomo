import Foundation
import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ClipboardImageWriterTests {
    @Test func clipboardFilesUseWritableTemporaryStorageInsteadOfDownloads() {
        let fileManager = FileManager.default
        let cacheDirectory = ClipboardImageWriter.clipboardCacheDirectory(fileManager: fileManager)
            .standardizedFileURL
        let temporaryDirectory = fileManager.temporaryDirectory.standardizedFileURL
        let downloadsDirectory = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)
            .first?
            .standardizedFileURL

        #expect(cacheDirectory.path.hasPrefix(temporaryDirectory.path + "/"))
        #expect(cacheDirectory.path.hasSuffix(ClipboardImageWriter.clipboardCacheFolderName))
        #expect(downloadsDirectory.map { !cacheDirectory.path.hasPrefix($0.path + "/") } ?? true)
    }

    @Test func copyingSelectionPreservesLayerFrameForPasteInPlace() throws {
        let canvas = solidImage(color: .black, size: CGSize(width: 120, height: 90))
        let viewModel = ImageEditorViewModel(sourceName: "selection-copy.png", image: canvas) { _ in }
        let sourceIndex = try #require(viewModel.document.selectedLayerIndex)
        let sourceFrame = CGRect(x: 18, y: 22, width: 24, height: 18)
        viewModel.document.layers[sourceIndex].image = solidImage(color: .systemOrange, size: sourceFrame.size)
        viewModel.document.layers[sourceIndex].frame = sourceFrame
        viewModel.document.selection = .rectangle(CGRect(x: 20, y: 24, width: 10, height: 8))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }

        viewModel.copySelectionToClipboard()

        #expect(viewModel.canPasteClipboardImageInPlace)
        #expect(XomoClipboardLayerPayload.frame(from: pasteboard) == sourceFrame)
        viewModel.pasteClipboardInPlaceAsLayer()
        #expect(viewModel.document.selectedLayer?.frame == sourceFrame)
    }

    @Test func copyingMergedPixelsPreservesCanvasFrameForPasteInPlace() throws {
        let canvasSize = CGSize(width: 96, height: 64)
        let viewModel = ImageEditorViewModel(
            sourceName: "merged-copy.png",
            image: solidImage(color: .systemBlue, size: canvasSize)
        ) { _ in }
        viewModel.document.selection = .rectangle(CGRect(x: 11, y: 9, width: 30, height: 24))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }

        viewModel.copyMergedToClipboard()

        #expect(viewModel.canPasteClipboardImageInPlace)
        #expect(
            XomoClipboardLayerPayload.frame(from: pasteboard)
                == CGRect(origin: .zero, size: canvasSize)
        )
    }

    private func solidImage(color: NSColor, size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            color.setFill()
            rect.fill()
            return true
        }
    }
}
