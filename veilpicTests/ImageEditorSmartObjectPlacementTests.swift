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
        let originalSelection = ImageEditorSelection.rectangle(
            CGRect(x: 5, y: 6, width: 16, height: 10)
        )
        viewModel.document.selection = originalSelection
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
        #expect(viewModel.document.selection == nil)
        #expect(viewModel.reselectableSelection == originalSelection)
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
        #expect(viewModel.document.selection == originalSelection)
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

    @Test func pastingClipboardImageCreatesSelectedSmartObjectInOneUndoStep() throws {
        let viewModel = makeViewModel()
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let historyCount = viewModel.document.history.count
        let originalSelection = ImageEditorSelection.rectangle(
            CGRect(x: 12, y: 14, width: 30, height: 20)
        )
        viewModel.document.selection = originalSelection
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("xomo-tests.paste-smart-object.\(UUID().uuidString)")
        )
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }
        let image = try #require(NSImage.rendered(size: CGSize(width: 24, height: 16)) { rect in
            NSColor.systemIndigo.setFill()
            rect.fill()
        })
        #expect(pasteboard.writeObjects([image]))

        #expect(viewModel.pasteClipboardAsSmartObject(from: pasteboard))
        let pasted = try #require(viewModel.document.selectedLayer)
        let content = try #require(pasted.smartObjectContent)
        let clipboardName = L10n.text("source.clipboard")

        #expect(viewModel.document.selectedLayerIDs == [pasted.id])
        #expect(viewModel.document.selection == nil)
        #expect(viewModel.reselectableSelection == originalSelection)
        #expect(pasted.isSmartObject)
        #expect(pasted.name == L10n.format("imageEditor.layer.smartObjectName", clipboardName))
        #expect(pasted.frame == CGRect(x: 88, y: 72, width: 24, height: 16))
        #expect(pasted.image.size == CGSize(width: 24, height: 16))
        #expect(content.originalSize == CGSize(width: 24, height: 16))
        #expect(content.sourceName == clipboardName)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.clipboardPasteSmartObject"
        ))
        #expect(viewModel.statusText == L10n.text(
            "imageEditor.status.clipboardPastedAsSmartObject"
        ))

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.selection == originalSelection)
        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.smartObjectContent?.sourceID == content.sourceID)
    }

    @Test func oversizedClipboardSmartObjectFitsCanvasAndKeepsNativeResetSize() throws {
        let viewModel = makeViewModel()
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("xomo-tests.paste-large-smart-object.\(UUID().uuidString)")
        )
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }
        let image = try #require(NSImage.rendered(size: CGSize(width: 400, height: 200)) { rect in
            NSColor.systemPink.setFill()
            rect.fill()
        })
        #expect(pasteboard.writeObjects([image]))

        #expect(viewModel.pasteClipboardAsSmartObject(from: pasteboard))
        let pasted = try #require(viewModel.document.selectedLayer)
        #expect(pasted.frame == CGRect(x: 0, y: 30, width: 200, height: 100))
        #expect(pasted.smartObjectContent?.originalSize == CGSize(width: 400, height: 200))
        #expect(viewModel.canResetSelectedSmartObjectTransform)

        viewModel.resetSelectedSmartObjectTransform()
        #expect(viewModel.document.selectedLayer?.frame == CGRect(
            x: -100,
            y: -20,
            width: 400,
            height: 200
        ))
        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.frame == pasted.frame)
    }

    @Test func emptyClipboardSmartObjectPastePreservesDocumentAndExistingRedo() {
        let viewModel = makeViewModel()
        viewModel.addLayer()
        viewModel.undo()
        #expect(viewModel.canRedo)
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("xomo-tests.empty-smart-object.\(UUID().uuidString)")
        )
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }
        let layerIDs = viewModel.document.layers.map(\.id)
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count

        #expect(!viewModel.pasteClipboardAsSmartObject(from: pasteboard))
        #expect(viewModel.document.layers.map(\.id) == layerIDs)
        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(viewModel.canRedo)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.clipboardImageMissing"))

        viewModel.redo()
        #expect(viewModel.document.layers.count == layerIDs.count + 1)
    }

    @Test func editMenuWiresClipboardSmartObjectPasteInEveryLanguage() throws {
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

        #expect(importSource.contains("func pasteClipboardAsSmartObject("))
        #expect(importSource.contains("commitEmbeddedSmartObjectPlacement("))
        #expect(commandsSource.contains("imageEditor.action.pasteClipboardAsSmartObject"))
        #expect(commandsSource.contains("actions?.pasteAsSmartObject()"))
        #expect(commandsSource.contains("actions?.canPasteAsSmartObject != true"))
        #expect(menuSource.contains(
            "pasteAsSmartObject: { viewModel.pasteClipboardAsSmartObject() }"
        ))
        #expect(menuSource.contains(
            "canPasteAsSmartObject: viewModel.canPasteClipboardImageAsSmartObject"
        ))
        for locale in ["zh-Hans", "en", "ja"] {
            let strings = try String(
                contentsOf: root.appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(strings.contains("\"imageEditor.action.pasteClipboardAsSmartObject\" ="))
            #expect(strings.contains("\"imageEditor.history.clipboardPasteSmartObject\" ="))
            #expect(strings.contains("\"imageEditor.status.clipboardPastedAsSmartObject\" ="))
            #expect(strings.contains("\"imageEditor.status.clipboardPasteSmartObjectFailed\" ="))
        }
    }

    @Test func smartObjectViaCopyCreatesIndependentSelectedSourceInOneUndoStep() throws {
        let viewModel = makeViewModel()
        let sourceImage = try #require(NSImage.rendered(
            size: CGSize(width: 36, height: 24)
        ) { rect in
            NSColor.systemOrange.setFill()
            rect.fill()
        })
        var original = ImageEditorLayer.smartObject(
            name: "Shared Logo",
            image: sourceImage,
            sourceName: "shared-logo.png"
        )
        original.frame = CGRect(x: 32, y: 38, width: 72, height: 48)
        original.opacity = 0.62
        original.style.strokeEnabled = true
        original.style.strokeWidth = 3
        original.mask = NSImage.opaqueMask(size: sourceImage.size)
        original.smartFilters = [
            ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.28)
        ]
        viewModel.document.layers = [original]
        viewModel.document.selectedLayerID = original.id
        viewModel.document.selectedLayerIDs = [original.id]
        let originalSourceID = try #require(original.smartObjectContent?.sourceID)
        let originalImageData = try #require(original.image.qingtuPNGData())
        let originalMaskData = try #require(original.mask?.qingtuPNGData())
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.canCreateSmartObjectViaCopy)
        #expect(viewModel.createSmartObjectViaCopy())
        let copy = try #require(viewModel.document.selectedLayer)
        let copyContent = try #require(copy.smartObjectContent)

        #expect(viewModel.document.layers.count == 2)
        #expect(copy.id != original.id)
        #expect(copyContent.sourceID != originalSourceID)
        #expect(copyContent.sourceName == original.smartObjectContent?.sourceName)
        #expect(copyContent.originalSize == original.smartObjectContent?.originalSize)
        #expect(copy.frame == original.frame)
        #expect(copy.opacity == original.opacity)
        #expect(copy.style.strokeEnabled == original.style.strokeEnabled)
        #expect(copy.style.strokeWidth == original.style.strokeWidth)
        #expect(copy.smartFilters == original.smartFilters)
        #expect(copy.mask?.qingtuPNGData() == originalMaskData)
        #expect(copy.name == L10n.format("imageEditor.layer.copyName", original.name))
        #expect(copy.image.qingtuPNGData() == originalImageData)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerSmartObjectViaCopy"
        ))
        #expect(viewModel.statusText == L10n.text(
            "imageEditor.status.layerSmartObjectCreatedViaCopy"
        ))

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == [original.id])
        #expect(viewModel.document.selectedLayerID == original.id)
        viewModel.redo()
        let restoredCopy = try #require(viewModel.document.selectedLayer)
        #expect(restoredCopy.id == copy.id)
        #expect(restoredCopy.smartObjectContent?.sourceID == copyContent.sourceID)

        let replacement = try #require(NSImage.rendered(
            size: CGSize(width: 18, height: 12)
        ) { rect in
            NSColor.systemPurple.setFill()
            rect.fill()
        })
        viewModel.replaceSelectedSmartObjectContents(
            replacement,
            sourceName: "independent-logo.png"
        )
        let untouchedOriginal = try #require(
            viewModel.document.layers.first { $0.id == original.id }
        )
        #expect(untouchedOriginal.smartObjectContent?.sourceID == originalSourceID)
        #expect(untouchedOriginal.image.qingtuPNGData() == originalImageData)
        #expect(viewModel.document.selectedLayer?.smartObjectContent?.sourceName == "independent-logo")
    }

    @Test func smartObjectViaCopyRejectsOrdinaryOrMultiLayerSelectionAtomically() throws {
        let viewModel = makeViewModel()
        viewModel.addLayer()
        viewModel.undo()
        #expect(viewModel.canRedo)
        let layerIDs = viewModel.document.layers.map(\.id)
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count

        #expect(!viewModel.canCreateSmartObjectViaCopy)
        #expect(!viewModel.createSmartObjectViaCopy())
        #expect(viewModel.document.layers.map(\.id) == layerIDs)
        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)

        let smartImage = try #require(NSImage.rendered(
            size: CGSize(width: 20, height: 14)
        ) { rect in
            NSColor.systemGreen.setFill()
            rect.fill()
        })
        let smart = ImageEditorLayer.smartObject(
            name: "Smart",
            image: smartImage,
            sourceName: "smart.png"
        )
        viewModel.document.layers.append(smart)
        viewModel.document.selectedLayerID = smart.id
        viewModel.document.selectedLayerIDs = [layerIDs[0], smart.id]
        #expect(!viewModel.canCreateSmartObjectViaCopy)
        #expect(!viewModel.createSmartObjectViaCopy())
        #expect(viewModel.document.layers.count == layerIDs.count + 1)
    }

    @Test func smartObjectViaCopyIsSharedByLayerMenusAndLocalized() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let menuSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let panelSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )
        let modelSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorViewModel.swift"),
            encoding: .utf8
        )

        for source in [menuSource, panelSource] {
            #expect(source.contains("imageEditor.action.layerSmartObjectViaCopy"))
            #expect(source.contains("viewModel.createSmartObjectViaCopy()"))
            #expect(source.contains("!viewModel.canCreateSmartObjectViaCopy"))
        }
        #expect(modelSource.contains("func createSmartObjectViaCopy() -> Bool"))
        #expect(modelSource.contains("sourceID: UUID()"))
        for locale in ["zh-Hans", "en", "ja"] {
            let strings = try String(
                contentsOf: root.appendingPathComponent(
                    "veilpic/\(locale).lproj/Localizable.strings"
                ),
                encoding: .utf8
            )
            #expect(strings.contains("\"imageEditor.action.layerSmartObjectViaCopy\" ="))
            #expect(strings.contains("\"imageEditor.history.layerSmartObjectViaCopy\" ="))
            #expect(strings.contains("\"imageEditor.status.layerSmartObjectCreatedViaCopy\" ="))
        }
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
