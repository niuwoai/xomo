import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSmartObjectPlacementTests {
    @Test func placementFitsOnlyOversizedSourcesWithoutChangingAspectRatio() {
        #expect(ImageEditorEmbeddedSmartObjectPlacementPolicy.frame(
            for: CGSize(width: 400, height: 200),
            in: CGSize(width: 200, height: 160)
        ) == CGRect(x: 0, y: 30, width: 200, height: 100))
        #expect(ImageEditorEmbeddedSmartObjectPlacementPolicy.frame(
            for: CGSize(width: 100, height: 400),
            in: CGSize(width: 200, height: 160)
        ) == CGRect(x: 80, y: 0, width: 40, height: 160))
        #expect(ImageEditorEmbeddedSmartObjectPlacementPolicy.frame(
            for: CGSize(width: 40, height: 20),
            in: CGSize(width: 200, height: 160)
        ) == CGRect(x: 80, y: 70, width: 40, height: 20))
    }

    @Test func policyAcceptsRasterSourcesWithoutSilentlyRasterizingSVG() throws {
        for path in [
            "/tmp/art.PNG",
            "/tmp/photo.jpg",
            "/tmp/photo.JPEG",
            "/tmp/scan.tif",
            "/tmp/scan.TIFF",
            "/tmp/photo.heic",
            "/tmp/asset.WEBP"
        ] {
            #expect(ImageEditorEmbeddedSmartObjectFilePolicy.supports(
                URL(fileURLWithPath: path)
            ))
        }
        #expect(!ImageEditorEmbeddedSmartObjectFilePolicy.supports(
            URL(fileURLWithPath: "/tmp/vector.svg")
        ))
        #expect(!ImageEditorEmbeddedSmartObjectFilePolicy.supports(
            URL(fileURLWithPath: "/tmp/design.psd")
        ))
        let remote = try #require(URL(string: "https://example.com/photo.png"))
        #expect(!ImageEditorEmbeddedSmartObjectFilePolicy.supports(remote))
    }

    @Test func placingRasterFileCreatesSelectedSmartObjectAtSourceSizeInOneUndoStep() throws {
        let viewModel = makeViewModel()
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let historyCount = viewModel.document.history.count
        let url = temporaryURL(extension: "png")
        defer { try? FileManager.default.removeItem(at: url) }
        try writePNG(size: CGSize(width: 24, height: 16), to: url)

        #expect(viewModel.placeEmbeddedSmartObjectFile(
            url,
            centeredAt: CGPoint(x: 70, y: 55)
        ))
        let placed = try #require(viewModel.document.selectedLayer)
        let content = try #require(placed.smartObjectContent)

        #expect(viewModel.document.selectedLayerIDs == [placed.id])
        #expect(placed.isSmartObject)
        #expect(placed.name == L10n.format(
            "imageEditor.layer.smartObjectName",
            url.deletingPathExtension().lastPathComponent
        ))
        #expect(placed.frame == CGRect(x: 58, y: 47, width: 24, height: 16))
        #expect(placed.image.size == CGSize(width: 24, height: 16))
        #expect(content.originalSize == CGSize(width: 24, height: 16))
        #expect(content.sourceName == url.deletingPathExtension().lastPathComponent)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.placeEmbeddedSmartObject"
        ))
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.placeEmbeddedSmartObject",
            content.sourceName
        ))

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.smartObjectContent?.sourceID == content.sourceID)
    }

    @Test func invalidPlacementDoesNotMutateDocumentOrConsumeExistingRedo() throws {
        let viewModel = makeViewModel()
        viewModel.addLayer()
        viewModel.undo()
        #expect(viewModel.canRedo)
        let layerIDs = viewModel.document.layers.map(\.id)
        let history = viewModel.document.history
        let corruptURL = temporaryURL(extension: "png")
        let svgURL = temporaryURL(extension: "svg")
        defer {
            try? FileManager.default.removeItem(at: corruptURL)
            try? FileManager.default.removeItem(at: svgURL)
        }
        try Data("not a png".utf8).write(to: corruptURL, options: .atomic)
        try Data("<svg xmlns='http://www.w3.org/2000/svg'/>".utf8)
            .write(to: svgURL, options: .atomic)

        #expect(!viewModel.placeEmbeddedSmartObjectFile(corruptURL))
        #expect(!viewModel.placeEmbeddedSmartObjectFile(svgURL))
        #expect(viewModel.document.layers.map(\.id) == layerIDs)
        #expect(viewModel.document.history == history)
        #expect(viewModel.canRedo)
        #expect(viewModel.statusText == L10n.text(
            "imageEditor.status.placeEmbeddedSmartObjectFailed"
        ))

        viewModel.redo()
        #expect(viewModel.document.layers.count == layerIDs.count + 1)
    }

    @Test func oversizedPlacementFitsCanvasWhileResetTransformRestoresSourceSize() throws {
        let viewModel = makeViewModel()
        let url = temporaryURL(extension: "png")
        defer { try? FileManager.default.removeItem(at: url) }
        try writePNG(size: CGSize(width: 400, height: 200), to: url)

        #expect(viewModel.placeEmbeddedSmartObjectFile(url))
        let placed = try #require(viewModel.document.selectedLayer)
        #expect(placed.frame == CGRect(x: 0, y: 30, width: 200, height: 100))
        #expect(placed.smartObjectContent?.originalSize == CGSize(width: 400, height: 200))

        viewModel.resetSelectedSmartObjectTransform()
        let reset = try #require(viewModel.document.selectedLayer)
        #expect(reset.frame == CGRect(x: -100, y: -20, width: 400, height: 200))
        #expect(reset.smartObjectContent?.originalSize == CGSize(width: 400, height: 200))

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.frame == placed.frame)
    }

    @Test func repeatedResetIsDisabledAndPreservesExistingRedo() throws {
        let viewModel = makeViewModel()
        let url = temporaryURL(extension: "png")
        defer { try? FileManager.default.removeItem(at: url) }
        try writePNG(size: CGSize(width: 400, height: 200), to: url)

        #expect(viewModel.placeEmbeddedSmartObjectFile(url))
        #expect(viewModel.canResetSelectedSmartObjectTransform)
        viewModel.resetSelectedSmartObjectTransform()
        let resetLayer = try #require(viewModel.document.selectedLayer)
        #expect(!viewModel.canResetSelectedSmartObjectTransform)

        viewModel.renameSelectedLayer(to: "Renamed Smart Object")
        viewModel.undo()
        #expect(viewModel.canRedo)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count

        viewModel.resetSelectedSmartObjectTransform()

        #expect(viewModel.document.selectedLayer?.frame == resetLayer.frame)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(viewModel.canRedo)

        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.name == "Renamed Smart Object")
    }

    @Test func multiSelectionResetsOnlyObjectsThatActuallyDiffer() throws {
        let viewModel = makeViewModel()
        let url = temporaryURL(extension: "png")
        defer { try? FileManager.default.removeItem(at: url) }
        try writePNG(size: CGSize(width: 400, height: 200), to: url)

        #expect(viewModel.placeEmbeddedSmartObjectFile(url))
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.resetSelectedSmartObjectTransform()
        let nativeFirstFrame = try #require(viewModel.document.selectedLayer?.frame)

        #expect(viewModel.placeEmbeddedSmartObjectFile(url))
        let secondID = try #require(viewModel.document.selectedLayerID)
        let fittedSecondFrame = try #require(viewModel.document.selectedLayer?.frame)
        viewModel.document.selectedLayerIDs = [firstID, secondID]
        viewModel.document.selectedLayerID = secondID

        viewModel.resetSelectedSmartObjectTransform()

        #expect(viewModel.document.layers.first { $0.id == firstID }?.frame == nativeFirstFrame)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.frame.size == CGSize(width: 400, height: 200))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartObjectResetTransform"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerSmartObjectTransformReset"))
        #expect(!viewModel.canResetSelectedSmartObjectTransform)

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == firstID }?.frame == nativeFirstFrame)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.frame == fittedSecondFrame)
    }

    @Test func identicalReplacementPreservesHistoryUndoAndExistingRedo() throws {
        let viewModel = makeViewModel()
        let url = temporaryURL(extension: "png")
        defer { try? FileManager.default.removeItem(at: url) }
        try writePNG(size: CGSize(width: 40, height: 20), to: url)

        #expect(viewModel.placeEmbeddedSmartObjectFile(url))
        let originalLayer = try #require(viewModel.document.selectedLayer)
        let replacement = try #require(NSImage(contentsOf: url))
        viewModel.renameSelectedLayer(to: "Renamed Smart Object")
        viewModel.undo()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count

        viewModel.replaceSelectedSmartObjectContents(
            replacement,
            sourceName: url.lastPathComponent
        )

        #expect(viewModel.document.selectedLayer?.image.qingtuPNGData() == originalLayer.image.qingtuPNGData())
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerSmartObjectContentsUnchanged"))
        #expect(viewModel.canRedo)

        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.name == "Renamed Smart Object")
    }

    @Test func multiSourceReplacementSkipsEquivalentFamilies() throws {
        let viewModel = makeViewModel()
        let firstURL = temporaryURL(extension: "png")
        let secondURL = temporaryURL(extension: "png")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        try writePNG(size: CGSize(width: 40, height: 20), to: firstURL)
        try writePNG(size: CGSize(width: 24, height: 16), to: secondURL)

        #expect(viewModel.placeEmbeddedSmartObjectFile(firstURL))
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.duplicateSelectedLayer()
        let sharedID = try #require(viewModel.document.selectedLayerID)
        #expect(viewModel.placeEmbeddedSmartObjectFile(secondURL))
        let differentID = try #require(viewModel.document.selectedLayerID)
        let differentBefore = try #require(viewModel.document.selectedLayer)
        viewModel.document.selectedLayerIDs = [firstID, differentID]
        viewModel.document.selectedLayerID = differentID
        let replacement = try #require(NSImage(contentsOf: firstURL))

        viewModel.replaceSelectedSmartObjectContents(
            replacement,
            sourceName: firstURL.lastPathComponent
        )

        let first = try #require(viewModel.document.layers.first { $0.id == firstID })
        let shared = try #require(viewModel.document.layers.first { $0.id == sharedID })
        let replaced = try #require(viewModel.document.layers.first { $0.id == differentID })
        #expect(first.smartObjectContent?.sourceName == firstURL.deletingPathExtension().lastPathComponent)
        #expect(shared.smartObjectContent?.sourceID == first.smartObjectContent?.sourceID)
        #expect(replaced.image.size == CGSize(width: 40, height: 20))
        #expect(replaced.smartObjectContent?.sourceName == first.smartObjectContent?.sourceName)
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.layerSmartObjectReplaced",
            firstURL.deletingPathExtension().lastPathComponent
        ))

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == differentID }?.image.size == differentBefore.image.size)
        #expect(viewModel.document.layers.first { $0.id == differentID }?.smartObjectContent?.sourceName == differentBefore.smartObjectContent?.sourceName)
    }

    @Test func fileMenuActionUsesSingleSelectionRasterChooserAndSharedCommandCatalog() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let importSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorImport.swift"),
            encoding: .utf8
        )
        let commandsSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )
        let menuSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )

        let chooserStart = try #require(importSource.range(
            of: "func chooseEmbeddedSmartObjectFile()"
        ))
        let chooserEnd = try #require(importSource[chooserStart.upperBound...].range(
            of: "func placeEmbeddedSmartObjectFile("
        ))
        let chooser = importSource[chooserStart.lowerBound..<chooserEnd.lowerBound]
        #expect(chooser.contains("panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .webP]"))
        #expect(chooser.contains("panel.allowsMultipleSelection = false"))
        #expect(chooser.contains("self.placeEmbeddedSmartObjectFile(url)"))
        #expect(commandsSource.contains("actions?.placeEmbeddedSmartObject()"))
        #expect(menuSource.contains(
            "placeEmbeddedSmartObject: { viewModel.chooseEmbeddedSmartObjectFile() }"
        ))
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "smart-placement.png",
            image: NSImage.transparent(size: CGSize(width: 200, height: 160))
        ) { _ in }
    }

    private func temporaryURL(extension pathExtension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-place-embedded-\(UUID().uuidString)")
            .appendingPathExtension(pathExtension)
    }

    private func writePNG(size: CGSize, to url: URL) throws {
        let image = try #require(NSImage.rendered(size: size) { rect in
            NSColor.systemTeal.setFill()
            rect.fill()
        })
        try #require(image.qingtuPNGData()).write(to: url, options: .atomic)
    }
}
