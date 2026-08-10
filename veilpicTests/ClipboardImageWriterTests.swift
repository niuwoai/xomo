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

    @Test func cuttingSelectionPreservesLayerFrameForPasteInPlace() throws {
        let canvas = solidImage(color: .clear, size: CGSize(width: 120, height: 90))
        let viewModel = ImageEditorViewModel(sourceName: "selection-cut.png", image: canvas) { _ in }
        let sourceIndex = try #require(viewModel.document.selectedLayerIndex)
        let sourceFrame = CGRect(x: 21, y: 17, width: 30, height: 24)
        viewModel.document.layers[sourceIndex].image = solidImage(color: .systemPink, size: sourceFrame.size)
        viewModel.document.layers[sourceIndex].frame = sourceFrame
        viewModel.document.selection = .rectangle(CGRect(x: 25, y: 21, width: 12, height: 10))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }

        viewModel.cutSelectionToClipboard()

        let clearedPixel = try #require(
            viewModel.document.layers[sourceIndex].image
                .color(at: CGPoint(x: 8, y: 8))?
                .usingColorSpace(.deviceRGB)
        )
        #expect(clearedPixel.alphaComponent < 0.05)
        #expect(viewModel.canPasteClipboardImageInPlace)
        #expect(XomoClipboardLayerPayload.frame(from: pasteboard) == sourceFrame)
        viewModel.pasteClipboardInPlaceAsLayer()
        #expect(viewModel.document.selectedLayer?.frame == sourceFrame)
    }

    @Test func ordinaryPasteKeepsNativeSizeWhenClipboardImageExceedsCanvas() throws {
        let canvasSize = CGSize(width: 80, height: 60)
        let clipboardSize = CGSize(width: 140, height: 100)
        let viewModel = ImageEditorViewModel(
            sourceName: "large-paste.png",
            image: solidImage(color: .white, size: canvasSize)
        ) { _ in }
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("xomo-tests.large-native-paste"))
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }
        let clipboardImage = try #require(
            bitmapImage(pixelSize: clipboardSize, logicalSize: clipboardSize)
        )
        #expect(pasteboard.writeObjects([clipboardImage]))

        viewModel.pasteClipboardAsLayer(from: pasteboard)

        #expect(viewModel.document.selectedLayer?.image.size == clipboardSize)
        #expect(
            viewModel.document.selectedLayer?.frame
                == CGRect(x: -30, y: -20, width: 140, height: 100)
        )
    }

    @Test func ordinaryPasteUsesBitmapPixelsInsteadOfHighDPIImagePoints() throws {
        let canvasSize = CGSize(width: 200, height: 100)
        let pixelSize = CGSize(width: 120, height: 60)
        let logicalSize = CGSize(width: 60, height: 30)
        let viewModel = ImageEditorViewModel(
            sourceName: "high-dpi-paste.png",
            image: solidImage(color: .white, size: canvasSize)
        ) { _ in }
        let clipboardImage = try #require(bitmapImage(pixelSize: pixelSize, logicalSize: logicalSize))
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("xomo-tests.high-dpi-paste"))
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }
        #expect(pasteboard.writeObjects([clipboardImage]))

        viewModel.pasteClipboardAsLayer(from: pasteboard)

        #expect(viewModel.document.selectedLayer?.image.size == pixelSize)
        #expect(
            viewModel.document.selectedLayer?.frame
                == CGRect(x: 40, y: 20, width: 120, height: 60)
        )
    }

    private func solidImage(color: NSColor, size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            color.setFill()
            rect.fill()
            return true
        }
    }

    private func bitmapImage(pixelSize: CGSize, logicalSize: CGSize) -> NSImage? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: Int(pixelSize.width) * 4,
            bitsPerPixel: 32
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }

        bitmap.size = logicalSize
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = context
        NSColor.systemTeal.setFill()
        CGRect(origin: .zero, size: logicalSize).fill()
        NSGraphicsContext.current = previous

        let image = NSImage(size: logicalSize)
        image.addRepresentation(bitmap)
        return image
    }
}
