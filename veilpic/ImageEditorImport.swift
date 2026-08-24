//
//  ImageEditorImport.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import UniformTypeIdentifiers

nonisolated enum ImageEditorLayerFileImportKind: Equatable {
    case rasterImage
    case editableSVG
}

nonisolated enum ImageEditorLayerFileImportPolicy {
    static func kind(for url: URL) -> ImageEditorLayerFileImportKind? {
        guard url.isFileURL else { return nil }
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg":
            return .rasterImage
        case "svg":
            return .editableSVG
        default:
            return nil
        }
    }

    static func singleSupportedURL(from urls: [URL]) -> URL? {
        guard urls.count == 1,
              let url = urls.first,
              kind(for: url) != nil
        else { return nil }
        return url
    }

    static func frame(for contentSize: CGSize, centeredAt point: CGPoint) -> CGRect {
        let safeSize = CGSize(
            width: max(1, contentSize.width),
            height: max(1, contentSize.height)
        )
        return CGRect(
            x: point.x - safeSize.width / 2,
            y: point.y - safeSize.height / 2,
            width: safeSize.width,
            height: safeSize.height
        )
    }
}

@MainActor
extension ImageEditorViewModel {
    var canPasteClipboardImage: Bool {
        NSPasteboard.general.readImage() != nil
    }

    var canPasteClipboardImageIntoSelection: Bool {
        canImportImageIntoSelection && canPasteClipboardImage
    }

    var canImportImageIntoSelection: Bool {
        importSelectionBounds != nil
    }

    var canPasteClipboardImageInPlace: Bool {
        canPasteClipboardImage && XomoClipboardLayerPayload.frame(from: .general) != nil
    }

    func chooseImageLayerFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .png,
            .jpeg,
            UTType(filenameExtension: "svg") ?? .xml
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = L10n.text("imageEditor.action.fileImport")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                self.importLayerFile(url)
            }
        }
    }

    @discardableResult
    func importLayerFile(_ url: URL, centeredAt point: CGPoint? = nil) -> Bool {
        guard let kind = ImageEditorLayerFileImportPolicy.kind(for: url) else {
            statusText = L10n.text("imageEditor.status.layerImportFailed")
            return false
        }

        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            statusText = L10n.text("imageEditor.status.layerImportFailed")
            return false
        }

        switch kind {
        case .editableSVG:
            guard let data = try? Data(contentsOf: url) else {
                statusText = L10n.text("imageEditor.status.editableSVGImportFailed")
                return false
            }
            return importEditableSVGLayer(
                data,
                sourceName: url.lastPathComponent,
                centeredAt: point
            )
        case .rasterImage:
            guard let image = NSImage(contentsOf: url) else {
                statusText = L10n.text("imageEditor.status.layerImportFailed")
                return false
            }
            return importImageLayer(
                image,
                sourceName: url.lastPathComponent,
                centeredAt: point
            )
        }
    }

    @discardableResult
    func importEditableSVGLayer(
        _ data: Data,
        sourceName: String,
        centeredAt point: CGPoint? = nil
    ) -> Bool {
        guard let imported = XomoEditableSVGImporter.parse(data) else {
            statusText = L10n.text("imageEditor.status.editableSVGImportFailed")
            return false
        }

        let cleanName = cleanLayerName(from: sourceName)
        pushUndo()
        var layer = ImageEditorLayer.shape(
            name: cleanName,
            frame: point.map {
                ImageEditorLayerFileImportPolicy.frame(for: imported.size, centeredAt: $0)
            } ?? centeredImportFrame(for: imported.size),
            content: imported.content
        )
        layer.groupID = nil
        layer.isClippingMask = false
        document.layers.append(layer)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.editableSVGImport"))
        statusText = L10n.format("imageEditor.status.editableSVGImported", cleanName)
        return true
    }

    func chooseSmartObjectReplacementFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = L10n.text("imageEditor.action.layerSmartObjectReplace")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                guard let image = NSImage(contentsOf: url) else {
                    self.statusText = L10n.text("imageEditor.status.layerSmartObjectReplaceFailed")
                    return
                }
                self.replaceSelectedSmartObjectContents(image, sourceName: url.lastPathComponent)
            }
        }
    }

    func chooseColorLookupCubeFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "cube") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = L10n.text("imageEditor.action.colorLookupImportCube")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                do {
                    let contents = try String(contentsOf: url, encoding: .utf8)
                    guard self.importColorLookupCube(name: url.deletingPathExtension().lastPathComponent, contents: contents) else {
                        self.statusText = L10n.text("imageEditor.status.colorLookupCubeImportFailed")
                        return
                    }
                    self.statusText = L10n.format(
                        "imageEditor.status.colorLookupCubeImported",
                        self.selectedColorLookupCube.name,
                        self.selectedColorLookupCube.dimension
                    )
                } catch {
                    self.statusText = L10n.text("imageEditor.status.colorLookupCubeImportFailed")
                }
            }
        }
    }

    @discardableResult
    func importColorLookupCube(name: String, contents: String) -> Bool {
        guard let cube = ImageEditorColorLookupCube.parse(contents, fallbackName: name) else {
            return false
        }
        selectedAdjustment = .colorLookup
        selectedColorLookupPreset = .customCube
        selectedColorLookupCube = cube
        return true
    }

    @discardableResult
    func pasteClipboardAsLayer(from pasteboard: NSPasteboard = .general) -> Bool {
        guard let image = pasteboard.readImage() else {
            statusText = L10n.text("imageEditor.status.clipboardImageMissing")
            return false
        }

        return importImageLayer(
            image,
            sourceName: L10n.text("source.clipboard"),
            historyTitle: L10n.text("imageEditor.history.clipboardPasteLayer"),
            importedStatus: L10n.text("imageEditor.status.clipboardPastedToLayer")
        )
    }

    @discardableResult
    func pasteClipboardIntoSelectionAsLayer(from pasteboard: NSPasteboard = .general) -> Bool {
        guard document.selection != nil else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return false
        }
        guard let image = pasteboard.readImage() else {
            statusText = L10n.text("imageEditor.status.clipboardImageMissing")
            return false
        }

        return importImageLayerIntoSelection(
            image,
            sourceName: L10n.text("source.clipboard"),
            historyTitle: L10n.text("imageEditor.history.clipboardPasteIntoSelection"),
            importedStatus: L10n.text("imageEditor.status.clipboardPastedIntoSelection")
        )
    }

    @discardableResult
    func pasteClipboardInPlaceAsLayer(from pasteboard: NSPasteboard = .general) -> Bool {
        guard let image = pasteboard.readImage() else {
            statusText = L10n.text("imageEditor.status.clipboardImageMissing")
            return false
        }
        guard let frame = XomoClipboardLayerPayload.frame(from: pasteboard) else {
            statusText = L10n.text("imageEditor.status.clipboardLayerPositionMissing")
            return false
        }

        return importImageLayer(
            image,
            sourceName: L10n.text("source.clipboard"),
            historyTitle: L10n.text("imageEditor.history.clipboardPasteLayer"),
            importedStatus: L10n.text("imageEditor.status.clipboardPastedInPlace"),
            frameOverride: frame
        )
    }

    @discardableResult
    func importImageLayer(
        _ image: NSImage,
        sourceName: String,
        historyTitle: String? = nil,
        importedStatus: String? = nil,
        frameOverride: CGRect? = nil,
        centeredAt point: CGPoint? = nil
    ) -> Bool {
        let normalized = image.normalizedImportedBitmapImage()
        guard normalized.size.width > 0, normalized.size.height > 0 else {
            statusText = L10n.text("imageEditor.status.layerImportFailed")
            return false
        }

        pushUndo()
        var layer = ImageEditorLayer.blank(
            name: L10n.format("imageEditor.layer.importedName", cleanLayerName(from: sourceName)),
            size: normalized.size
        )
        layer.image = normalized
        layer.frame = frameOverride
            ?? point.map { ImageEditorLayerFileImportPolicy.frame(for: normalized.size, centeredAt: $0) }
            ?? centeredImportFrame(for: normalized.size)
        layer.opacity = 1
        layer.blendMode = .normal
        layer.groupID = nil
        layer.isClippingMask = false
        document.layers.append(layer)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(historyTitle ?? L10n.text("imageEditor.history.layerImport"))
        statusText = importedStatus ?? L10n.format("imageEditor.status.layerImported", cleanLayerName(from: sourceName))
        return true
    }

    @discardableResult
    func importImageLayerIntoSelection(
        _ image: NSImage,
        sourceName: String,
        historyTitle: String? = nil,
        importedStatus: String? = nil
    ) -> Bool {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return false
        }

        let normalized = image.normalizedImportedBitmapImage()
        guard normalized.size.width > 0, normalized.size.height > 0 else {
            statusText = L10n.text("imageEditor.status.layerImportFailed")
            return false
        }

        guard let selectedBounds = selection.effectiveSelectedBounds(in: document.canvasSize) else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return false
        }

        let layerFrame = fittedImportFrame(for: normalized.size, inside: selectedBounds)
        guard let layerMask = selectionMaskForImportedLayer(
            selection,
            layerFrame: layerFrame,
            layerSize: normalized.size
        ) else {
            statusText = L10n.text("imageEditor.status.layerImportFailed")
            return false
        }

        pushUndo()
        var layer = ImageEditorLayer.blank(
            name: L10n.format("imageEditor.layer.importedName", cleanLayerName(from: sourceName)),
            size: normalized.size
        )
        layer.image = normalized
        layer.frame = layerFrame
        layer.mask = layerMask
        layer.isMaskEnabled = true
        layer.isMaskLinked = true
        layer.maskDensity = 1
        layer.maskFeather = 0
        layer.opacity = 1
        layer.blendMode = .normal
        layer.groupID = nil
        layer.isClippingMask = false
        document.layers.append(layer)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(historyTitle ?? L10n.text("imageEditor.history.clipboardPasteIntoSelection"))
        statusText = importedStatus ?? L10n.format("imageEditor.status.layerImported", cleanLayerName(from: sourceName))
        return true
    }

    func replaceSelectedSmartObjectContents(_ image: NSImage, sourceName: String) {
        let sourceIDs = smartObjectReplacementTargetSourceIDs()
        guard !sourceIDs.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let normalized = image.normalizedImportedBitmapImage()
        guard normalized.size.width > 0, normalized.size.height > 0 else {
            statusText = L10n.text("imageEditor.status.layerSmartObjectReplaceFailed")
            return
        }

        let cleanSourceName = cleanLayerName(from: sourceName)
        pushUndo()
        var replacedCount = 0
        for layerIndex in document.layers.indices {
            guard let content = document.layers[layerIndex].smartObjectContent,
                  sourceIDs.contains(content.sourceID)
            else { continue }
            document.layers[layerIndex].image = normalized
            document.layers[layerIndex].kind = .smartObject(
                ImageEditorSmartObjectContent(
                    sourceName: cleanSourceName,
                    originalSize: normalized.size,
                    sourceID: content.sourceID
                )
            )
            replacedCount += 1
        }
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerSmartObjectReplace"))
        if replacedCount > 1 {
            statusText = L10n.format("imageEditor.status.layerSmartObjectInstancesReplaced", replacedCount, cleanSourceName)
        } else {
            statusText = L10n.format("imageEditor.status.layerSmartObjectReplaced", cleanSourceName)
        }
    }

    private func cleanLayerName(from sourceName: String) -> String {
        let cleanedSourceName = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = (cleanedSourceName as NSString).deletingPathExtension
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.text("imageEditor.layer.importedFallbackName") : trimmed
    }

    private func centeredImportFrame(for imageSize: CGSize) -> CGRect {
        let safeCanvasWidth = max(document.canvasSize.width, 1)
        let safeCanvasHeight = max(document.canvasSize.height, 1)
        let outputSize = CGSize(
            width: max(1, imageSize.width),
            height: max(1, imageSize.height)
        )
        return CGRect(
            x: (safeCanvasWidth - outputSize.width) / 2,
            y: (safeCanvasHeight - outputSize.height) / 2,
            width: outputSize.width,
            height: outputSize.height
        )
    }

    private func fittedImportFrame(for imageSize: CGSize, inside bounds: CGRect) -> CGRect {
        let safeBounds = bounds.standardized
        let widthScale = max(safeBounds.width, 1) / max(imageSize.width, 1)
        let heightScale = max(safeBounds.height, 1) / max(imageSize.height, 1)
        let scale = min(widthScale, heightScale)
        let outputSize = CGSize(
            width: max(1, imageSize.width * scale),
            height: max(1, imageSize.height * scale)
        )
        return CGRect(
            x: safeBounds.midX - outputSize.width / 2,
            y: safeBounds.midY - outputSize.height / 2,
            width: outputSize.width,
            height: outputSize.height
        )
    }

    private func selectionMaskForImportedLayer(
        _ selection: ImageEditorSelection,
        layerFrame: CGRect,
        layerSize: CGSize
    ) -> NSImage? {
        guard layerSize.width > 0,
              layerSize.height > 0,
              layerFrame.width > 0,
              layerFrame.height > 0,
              let canvasMask = canvasSelectionMaskForImport(selection)
        else { return nil }

        return NSImage.rendered(size: layerSize) { _ in
            canvasMask.draw(
                in: CGRect(origin: .zero, size: layerSize),
                from: layerFrame,
                operation: .copy,
                fraction: 1
            )
        }
    }

    private var importSelectionBounds: CGRect? {
        document.selection?.effectiveSelectedBounds(in: document.canvasSize)
    }

    private func canvasSelectionMaskForImport(_ selection: ImageEditorSelection) -> NSImage? {
        if let rasterMask = selection.rasterMask,
           let image = NSImage.selectionMaskImage(
            rasterMask,
            inverted: selection.isInverted,
            targetSize: document.canvasSize
           ) {
            guard feather > 0 else { return image }
            return image.blurred(radius: feather) ?? image
        }

        let hardMask = NSImage.rendered(size: document.canvasSize) { rect in
            let path = selection.path()
            if selection.isInverted {
                NSColor.white.setFill()
                rect.fill()
                guard let context = NSGraphicsContext.current?.cgContext else { return }
                context.saveGState()
                context.setBlendMode(.clear)
                NSColor.clear.setFill()
                path.fill()
                context.restoreGState()
            } else {
                NSColor.white.setFill()
                path.fill()
            }
        }
        guard let hardMask, feather > 0 else { return hardMask }
        return hardMask.blurred(radius: feather) ?? hardMask
    }
}
