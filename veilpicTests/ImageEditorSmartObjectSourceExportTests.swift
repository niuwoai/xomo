import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSmartObjectSourceExportTests {
    @Test func exportsUntransformedSourcePixelsAsPNGWithoutEditingDocument() throws {
        let viewModel = makeViewModel()
        let sourceImage = try #require(NSImage.rendered(
            size: CGSize(width: 36, height: 24)
        ) { rect in
            NSColor.systemOrange.setFill()
            rect.fill()
        })
        var smartObject = ImageEditorLayer.smartObject(
            name: "Scaled Logo",
            image: sourceImage,
            sourceName: "assets/logo.final.jpg"
        )
        smartObject.frame = CGRect(x: 18, y: 22, width: 108, height: 72)
        smartObject.opacity = 0.35
        smartObject.style.strokeEnabled = true
        smartObject.mask = NSImage.rendered(size: sourceImage.size) { rect in
            NSColor.clear.setFill()
            rect.fill()
            NSColor.white.setFill()
            CGRect(x: 0, y: 0, width: rect.width / 2, height: rect.height).fill()
        }
        smartObject.smartFilters = [
            ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.4)
        ]
        viewModel.document.layers = [smartObject]
        viewModel.document.selectedLayerID = smartObject.id
        viewModel.document.selectedLayerIDs = [smartObject.id]
        let layerIDs = viewModel.document.layers.map(\.id)
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count
        let expectedData = try #require(sourceImage.qingtuPNGData())
        let destination = temporaryURL(extension: "png")
        defer { try? FileManager.default.removeItem(at: destination) }

        #expect(viewModel.canExportSelectedSmartObjectSourcePNG)
        #expect(viewModel.selectedSmartObjectSourcePNGFilename() == "logo.final.png")
        #expect(viewModel.writeSelectedSmartObjectSourcePNG(to: destination))
        let exportedData = try Data(contentsOf: destination)
        let bitmap = try #require(NSBitmapImageRep(data: exportedData))

        #expect(exportedData == expectedData)
        #expect(bitmap.pixelsWide == 36)
        #expect(bitmap.pixelsHigh == 24)
        #expect(viewModel.document.layers.map(\.id) == layerIDs)
        #expect(viewModel.document.layers.first?.frame == smartObject.frame)
        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.smartObjectSourcePNGExported",
            destination.lastPathComponent
        ))
    }

    @Test func invalidSelectionDestinationAndWriterFailureStayAtomic() throws {
        let viewModel = makeViewModel()
        viewModel.addLayer()
        viewModel.undo()
        #expect(viewModel.canRedo)
        let layerIDs = viewModel.document.layers.map(\.id)
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count
        var writeCount = 0

        #expect(!viewModel.canExportSelectedSmartObjectSourcePNG)
        #expect(!viewModel.writeSelectedSmartObjectSourcePNG(
            to: temporaryURL(extension: "png"),
            dataWriter: { _, _ in writeCount += 1 }
        ))
        #expect(writeCount == 0)
        #expect(viewModel.document.layers.map(\.id) == layerIDs)

        let image = try #require(NSImage.rendered(size: CGSize(width: 20, height: 12)) { rect in
            NSColor.systemTeal.setFill()
            rect.fill()
        })
        let smartObject = ImageEditorLayer.smartObject(
            name: "Source",
            image: image,
            sourceName: "source.png"
        )
        viewModel.document.layers = [smartObject]
        viewModel.document.selectedLayerID = smartObject.id
        viewModel.document.selectedLayerIDs = [smartObject.id]
        let smartLayerIDs = viewModel.document.layers.map(\.id)

        #expect(!viewModel.writeSelectedSmartObjectSourcePNG(
            to: temporaryURL(extension: "jpg"),
            dataWriter: { _, _ in writeCount += 1 }
        ))
        #expect(writeCount == 0)
        #expect(!viewModel.writeSelectedSmartObjectSourcePNG(
            to: temporaryURL(extension: "png"),
            dataWriter: { _, _ in throw TestWriteError.expected }
        ))
        #expect(viewModel.document.history == history)
        #expect(viewModel.document.layers.map(\.id) == smartLayerIDs)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(viewModel.canRedo)
    }

    @Test func filenamePolicyMenusPanelAndLocalizationsShareThePNGContract() throws {
        #expect(ImageEditorSmartObjectSourcePNGExportPolicy.filename(
            sourceName: " folder/brand.logo.jpeg "
        ) == "brand.logo.png")
        #expect(ImageEditorSmartObjectSourcePNGExportPolicy.filename(
            sourceName: "  "
        ) == "smart-object.png")
        #expect(ImageEditorSmartObjectSourcePNGExportPolicy.supports(
            URL(fileURLWithPath: "/tmp/source.PNG")
        ))
        #expect(!ImageEditorSmartObjectSourcePNGExportPolicy.supports(
            URL(fileURLWithPath: "/tmp/source.jpg")
        ))

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let exportSource = try String(
            contentsOf: root.appendingPathComponent(
                "veilpic/ImageEditorSmartObjectSourceExport.swift"
            ),
            encoding: .utf8
        )
        let menuSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let panelSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )

        #expect(exportSource.contains("panel.allowedContentTypes = [.png]"))
        #expect(exportSource.contains("selectedSmartObjectSourceExportLayer()?.image.qingtuPNGData()"))
        #expect(exportSource.contains("ImageEditorFilePanelKeyboardFocusRestorer.restore"))
        for source in [menuSource, panelSource] {
            #expect(source.contains("imageEditor.action.smartObjectSourcePNGExport"))
            #expect(source.contains("viewModel.chooseSmartObjectSourcePNGDestination()"))
            #expect(source.contains("!viewModel.canExportSelectedSmartObjectSourcePNG"))
        }
        for locale in ["zh-Hans", "en", "ja"] {
            let strings = try String(
                contentsOf: root.appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(strings.contains("\"imageEditor.action.smartObjectSourcePNGExport\" ="))
            #expect(strings.contains("\"imageEditor.status.smartObjectSourcePNGExported\" ="))
            #expect(strings.contains("\"imageEditor.status.smartObjectSourcePNGExportFailed\" ="))
            #expect(strings.contains(
                "\"imageEditor.status.smartObjectSourcePNGExportFailedWithReason\" ="
            ))
        }
    }

    private enum TestWriteError: Error {
        case expected
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "smart-object-source-export",
            image: .transparent(size: CGSize(width: 200, height: 160))
        ) { _ in }
    }

    private func temporaryURL(extension pathExtension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-smart-object-source-\(UUID().uuidString)")
            .appendingPathExtension(pathExtension)
    }
}
