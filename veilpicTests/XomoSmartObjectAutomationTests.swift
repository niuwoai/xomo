import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct XomoSmartObjectAutomationTests {
    @Test func placeEmbeddedUsesTheValidatedFileWorkflow() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let url = temporaryURL(extension: "png")
        defer { try? FileManager.default.removeItem(at: url) }
        try writePNG(size: CGSize(width: 400, height: 200), to: url)
        let initialLayerCount = viewModel.document.layers.count

        let response = registry.execute(request(arguments: [
            "action": .string("placeEmbedded"),
            "path": .string(url.path)
        ]))

        #expect(response.ok)
        let layer = try #require(viewModel.document.selectedLayer)
        #expect(layer.isSmartObject)
        #expect(layer.frame == CGRect(x: 0, y: 40, width: 320, height: 160))
        #expect(layer.smartObjectContent?.originalSize == CGSize(width: 400, height: 200))
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.placeEmbeddedSmartObject"
        ))
        viewModel.undo()
        #expect(viewModel.document.layers.count == initialLayerCount)
    }

    @Test func schemaAdvertisesPathAndInvalidFilesStayAtomic() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let tools = registry.execute(XomoAutomationWireRequest(
            token: "test",
            operation: "tools",
            name: nil,
            arguments: nil
        ))
        let tool = try #require(tools.result?.arrayValue?.compactMap(\.objectValue).first {
            $0["name"] == .string("xomo.layer.smart_object")
        })
        let properties = try #require(
            tool["inputSchema"]?.objectValue?["properties"]?.objectValue
        )
        #expect(properties["action"]?.objectValue?["enum"]?.arrayValue?.contains(
            .string("placeEmbedded")
        ) == true)
        #expect(properties["action"]?.objectValue?["enum"]?.arrayValue?.contains(
            .string("newViaCopy")
        ) == true)
        #expect(properties["action"]?.objectValue?["enum"]?.arrayValue?.contains(
            .string("exportSourcePNG")
        ) == true)
        #expect(properties["path"]?.objectValue?["type"] == .string("string"))

        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        let layerCount = viewModel.document.layers.count
        let corruptURL = temporaryURL(extension: "png")
        defer { try? FileManager.default.removeItem(at: corruptURL) }
        try Data([0x58, 0x4F, 0x4D, 0x4F]).write(to: corruptURL)

        let failed = registry.execute(request(arguments: [
            "action": .string("placeEmbedded"),
            "path": .string(corruptURL.path)
        ]))

        #expect(!failed.ok)
        #expect(viewModel.document.layers.count == layerCount)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
    }

    @Test func newViaCopyAutomationCreatesIndependentSourceAndSupportsOneUndo() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let image = try #require(NSImage.rendered(size: CGSize(width: 44, height: 28)) { rect in
            NSColor.systemOrange.setFill()
            rect.fill()
        })
        var original = ImageEditorLayer.smartObject(
            name: "Automation Logo",
            image: image,
            sourceName: "automation-logo.png"
        )
        original.frame = CGRect(x: 40, y: 52, width: 88, height: 56)
        viewModel.document.layers = [original]
        viewModel.document.selectedLayerID = original.id
        viewModel.document.selectedLayerIDs = [original.id]
        let originalSourceID = try #require(original.smartObjectContent?.sourceID)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        let response = registry.execute(request(arguments: [
            "action": .string("newViaCopy")
        ]))

        #expect(response.ok)
        let copy = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.count == 2)
        #expect(copy.id != original.id)
        #expect(copy.smartObjectContent?.sourceID != originalSourceID)
        #expect(copy.smartObjectContent?.sourceName == original.smartObjectContent?.sourceName)
        #expect(copy.frame == original.frame)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerSmartObjectViaCopy"
        ))

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == [original.id])
        #expect(viewModel.document.selectedLayerID == original.id)
    }

    @Test func newViaCopyAutomationRejectsInvalidSelectionWithoutConsumingRedo() {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        viewModel.addLayer()
        viewModel.undo()
        #expect(viewModel.canRedo)
        let layerIDs = viewModel.document.layers.map(\.id)
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count

        let response = registry.execute(request(arguments: [
            "action": .string("newViaCopy")
        ]))

        #expect(!response.ok)
        #expect(viewModel.document.layers.map(\.id) == layerIDs)
        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(viewModel.canRedo)
    }

    @Test func exportSourcePNGAutomationWritesExactSourcePixelsWithoutEditingDocument() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let sourceImage = try #require(NSImage.rendered(
            size: CGSize(width: 44, height: 28)
        ) { rect in
            NSColor.systemOrange.setFill()
            rect.fill()
        })
        var smartObject = ImageEditorLayer.smartObject(
            name: "Automation Source",
            image: sourceImage,
            sourceName: "automation-source.jpeg"
        )
        smartObject.frame = CGRect(x: 20, y: 30, width: 132, height: 84)
        smartObject.opacity = 0.4
        smartObject.smartFilters = [
            ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.5)
        ]
        viewModel.document.layers = [smartObject]
        viewModel.document.selectedLayerID = smartObject.id
        viewModel.document.selectedLayerIDs = [smartObject.id]
        let expectedData = try #require(sourceImage.qingtuPNGData())
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count
        let destination = temporaryURL(extension: "png")
        defer { try? FileManager.default.removeItem(at: destination) }

        let response = registry.execute(request(arguments: [
            "action": .string("exportSourcePNG"),
            "path": .string(destination.path)
        ]))

        #expect(response.ok)
        let exportedData = try Data(contentsOf: destination)
        let bitmap = try #require(NSBitmapImageRep(data: exportedData))
        #expect(exportedData == expectedData)
        #expect(bitmap.pixelsWide == 44)
        #expect(bitmap.pixelsHigh == 28)
        #expect(viewModel.document.layers.count == 1)
        #expect(viewModel.document.selectedLayer?.id == smartObject.id)
        #expect(viewModel.document.selectedLayer?.frame == smartObject.frame)
        #expect(viewModel.document.selectedLayer?.smartObjectContent?.sourceID ==
            smartObject.smartObjectContent?.sourceID)
        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
    }

    @Test func exportSourcePNGAutomationFailurePreservesExistingFileAndRedo() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        viewModel.addLayer()
        viewModel.undo()
        #expect(viewModel.canRedo)
        let marker = Data([0x58, 0x4F, 0x4D, 0x4F])
        let destination = temporaryURL(extension: "png")
        defer { try? FileManager.default.removeItem(at: destination) }
        try marker.write(to: destination, options: .atomic)
        let layerIDs = viewModel.document.layers.map(\.id)
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count

        let response = registry.execute(request(arguments: [
            "action": .string("exportSourcePNG"),
            "path": .string(destination.path)
        ]))

        #expect(!response.ok)
        #expect(try Data(contentsOf: destination) == marker)
        #expect(viewModel.document.layers.map(\.id) == layerIDs)
        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(viewModel.canRedo)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "automation",
            image: .transparent(size: CGSize(width: 320, height: 240))
        ) { _ in }
    }

    private func request(
        arguments: [String: XomoJSONValue]
    ) -> XomoAutomationWireRequest {
        XomoAutomationWireRequest(
            token: "test",
            operation: "call",
            name: "xomo.layer.smart_object",
            arguments: arguments
        )
    }

    private func temporaryURL(extension pathExtension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-smart-object-automation-\(UUID().uuidString)")
            .appendingPathExtension(pathExtension)
    }

    private func writePNG(size: CGSize, to url: URL) throws {
        let image = NSImage.rendered(size: size) { rect in
            NSColor.systemIndigo.setFill()
            rect.fill()
        } ?? NSImage(size: size)
        try #require(image.qingtuPNGData()).write(to: url, options: .atomic)
    }
}
