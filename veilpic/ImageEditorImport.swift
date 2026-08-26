//
//  ImageEditorImport.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import UniformTypeIdentifiers

@MainActor
enum ImageEditorFilePanelKeyboardFocusRestorer {
    typealias DeferredRestoreScheduler = (@escaping @MainActor () -> Void) -> Void

    static func restore(to window: NSWindow?) {
        restore(
            to: window,
            isApplicationActive: NSApp.isActive,
            deferredApplicationActivity: { NSApp.isActive },
            scheduleDeferredRestore: { action in
                RunLoop.main.perform {
                    MainActor.assumeIsolated {
                        action()
                    }
                }
            }
        )
    }

    static func restore(
        to window: NSWindow?,
        isApplicationActive: Bool,
        deferredApplicationActivity: @escaping @MainActor () -> Bool = { NSApp.isActive },
        scheduleDeferredRestore: DeferredRestoreScheduler? = nil
    ) {
        restoreImmediately(to: window, isApplicationActive: isApplicationActive)
        scheduleDeferredRestore? { [weak window] in
            restoreImmediately(
                to: window,
                isApplicationActive: deferredApplicationActivity()
            )
        }
    }

    private static func restoreImmediately(
        to window: NSWindow?,
        isApplicationActive: Bool
    ) {
        guard isApplicationActive, let window, window.isVisible else { return }
        window.makeKeyAndOrderFront(nil)
        if let keyboardResponder = keyboardResponder(in: window.contentView) {
            window.makeFirstResponder(keyboardResponder)
        } else {
            window.makeFirstResponder(nil)
        }
    }

    private static func keyboardResponder(
        in view: NSView?
    ) -> ImageEditorKeyboardShortcutResponderNSView? {
        guard let view else { return nil }
        if let responder = view as? ImageEditorKeyboardShortcutResponderNSView {
            return responder
        }
        for subview in view.subviews {
            if let responder = keyboardResponder(in: subview) {
                return responder
            }
        }
        return nil
    }
}

nonisolated enum ImageEditorLayerFileImportKind: Equatable {
    case rasterImage
    case editableSVG
}

nonisolated enum ImageEditorLayerFileImportPolicy {
    static let batchSpacing: CGFloat = 16

    static func kind(for url: URL) -> ImageEditorLayerFileImportKind? {
        guard url.isFileURL else { return nil }
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "tif", "tiff", "heic", "webp":
            return .rasterImage
        case "svg":
            return .editableSVG
        default:
            return nil
        }
    }

    static func supportedURLs(from urls: [URL]) -> [URL]? {
        guard !urls.isEmpty, urls.allSatisfy({ kind(for: $0) != nil }) else { return nil }
        return urls
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

    static func batchFrames(for contentSizes: [CGSize], centeredAt point: CGPoint) -> [CGRect] {
        guard !contentSizes.isEmpty else { return [] }
        let safeSizes = contentSizes.map {
            CGSize(width: max(1, $0.width), height: max(1, $0.height))
        }
        let contentWidth = safeSizes.reduce(CGFloat.zero) { $0 + $1.width }
        let spacingWidth = batchSpacing * CGFloat(max(0, safeSizes.count - 1))
        var nextX = point.x - (contentWidth + spacingWidth) / 2
        return safeSizes.map { size in
            defer { nextX += size.width + batchSpacing }
            return CGRect(
                x: nextX,
                y: point.y - size.height / 2,
                width: size.width,
                height: size.height
            )
        }
    }
}

nonisolated enum ImageEditorEmbeddedSmartObjectFilePolicy {
    static func supports(_ url: URL) -> Bool {
        ImageEditorLayerFileImportPolicy.kind(for: url) == .rasterImage
    }
}

nonisolated enum ImageEditorSmartObjectReplacementResult: Equatable {
    case changed
    case unchanged
    case failed

    var succeeded: Bool {
        self != .failed
    }
}

nonisolated enum ImageEditorEmbeddedSmartObjectPlacementPolicy {
    static func frame(for contentSize: CGSize, in canvasSize: CGSize) -> CGRect {
        let safeContentSize = CGSize(
            width: max(1, contentSize.width),
            height: max(1, contentSize.height)
        )
        let safeCanvasSize = CGSize(
            width: max(1, canvasSize.width),
            height: max(1, canvasSize.height)
        )
        let scale = min(
            1,
            safeCanvasSize.width / safeContentSize.width,
            safeCanvasSize.height / safeContentSize.height
        )
        let placedSize = CGSize(
            width: safeContentSize.width * scale,
            height: safeContentSize.height * scale
        )
        return CGRect(
            x: (safeCanvasSize.width - placedSize.width) / 2,
            y: (safeCanvasSize.height - placedSize.height) / 2,
            width: placedSize.width,
            height: placedSize.height
        )
    }
}

private enum ImageEditorPreparedLayerFileImport {
    case raster(sourceName: String, image: NSImage)
    case editableSVG(sourceName: String, imported: XomoEditableSVGImport)

    var size: CGSize {
        switch self {
        case .raster(_, let image):
            return image.size
        case .editableSVG(_, let imported):
            return imported.size
        }
    }
}

@MainActor
extension ImageEditorViewModel {
    var canPasteClipboardImage: Bool {
        canPasteClipboardImage(from: .general)
    }

    func canPasteClipboardImage(from pasteboard: NSPasteboard) -> Bool {
        XomoLayerClipboardArchive.containsSupportedData(in: pasteboard)
            || pasteboard.readImage() != nil
    }

    var canPasteClipboardImageIntoSelection: Bool {
        canImportImageIntoSelection && canPasteClipboardImage
    }

    var canImportImageIntoSelection: Bool {
        importSelectionBounds != nil
    }

    var canPasteClipboardImageInPlace: Bool {
        XomoLayerClipboardArchive.containsSupportedData(in: .general)
            || (NSPasteboard.general.readImage() != nil
                && XomoClipboardLayerPayload.frame(from: .general) != nil)
    }

    var canPasteClipboardImageAsSmartObject: Bool {
        canPasteClipboardImage
    }

    func chooseImageLayerFile() {
        let originatingWindow = NSApp.keyWindow
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .png,
            .jpeg,
            .tiff,
            .heic,
            .webP,
            UTType(filenameExtension: "svg") ?? .xml
        ]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = L10n.text("imageEditor.action.fileImport")
        panel.begin { [weak self] response in
            Task { @MainActor in
                defer {
                    ImageEditorFilePanelKeyboardFocusRestorer.restore(to: originatingWindow)
                }
                guard let self, response == .OK, !panel.urls.isEmpty else { return }
                self.importLayerFiles(panel.urls)
            }
        }
    }

    func chooseEmbeddedSmartObjectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .webP]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = L10n.text("imageEditor.action.placeEmbeddedSmartObject")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                self.placeEmbeddedSmartObjectFile(url)
            }
        }
    }

    @discardableResult
    func placeEmbeddedSmartObjectFile(
        _ url: URL,
        centeredAt point: CGPoint? = nil
    ) -> Bool {
        guard ImageEditorEmbeddedSmartObjectFilePolicy.supports(url),
              let prepared = prepareLayerFileImport(url),
              case .raster(let sourceName, let image) = prepared
        else {
            statusText = L10n.text("imageEditor.status.placeEmbeddedSmartObjectFailed")
            return false
        }

        guard let cleanName = commitEmbeddedSmartObjectPlacement(
            image,
            sourceName: sourceName,
            centeredAt: point,
            historyTitle: L10n.text("imageEditor.history.placeEmbeddedSmartObject")
        ) else {
            statusText = L10n.text("imageEditor.status.placeEmbeddedSmartObjectFailed")
            return false
        }
        statusText = L10n.format("imageEditor.status.placeEmbeddedSmartObject", cleanName)
        return true
    }

    @discardableResult
    func pasteClipboardAsSmartObject(
        from pasteboard: NSPasteboard = .general
    ) -> Bool {
        guard let image = pasteboard.readImage() else {
            statusText = L10n.text("imageEditor.status.clipboardImageMissing")
            return false
        }
        guard commitEmbeddedSmartObjectPlacement(
            image,
            sourceName: L10n.text("source.clipboard"),
            historyTitle: L10n.text("imageEditor.history.clipboardPasteSmartObject")
        ) != nil else {
            statusText = L10n.text("imageEditor.status.clipboardPasteSmartObjectFailed")
            return false
        }
        statusText = L10n.text("imageEditor.status.clipboardPastedAsSmartObject")
        return true
    }

    private func commitEmbeddedSmartObjectPlacement(
        _ image: NSImage,
        sourceName: String,
        centeredAt point: CGPoint? = nil,
        historyTitle: String
    ) -> String? {
        let normalized = image.normalizedImportedBitmapImage()
        guard normalized.size.width > 0, normalized.size.height > 0 else { return nil }

        let cleanName = cleanLayerName(from: sourceName)
        let frame = point.map {
            ImageEditorLayerFileImportPolicy.frame(for: normalized.size, centeredAt: $0)
        } ?? ImageEditorEmbeddedSmartObjectPlacementPolicy.frame(
            for: normalized.size,
            in: document.canvasSize
        )
        var layer = ImageEditorLayer.smartObject(
            name: L10n.format("imageEditor.layer.smartObjectName", cleanName),
            image: normalized,
            sourceName: cleanName
        )
        layer.frame = frame
        layer.groupID = nil
        layer.isClippingMask = false

        pushUndo()
        endPixelSelectionForImportedObject()
        document.layers.append(layer)
        selectImportedLayers([layer.id], primaryLayerID: layer.id)
        appendHistory(historyTitle)
        return cleanName
    }

    @discardableResult
    func importLayerFile(_ url: URL, centeredAt point: CGPoint? = nil) -> Bool {
        guard let prepared = prepareLayerFileImport(url) else { return false }
        switch prepared {
        case .editableSVG(let sourceName, let imported):
            return commitEditableSVGImport(imported, sourceName: sourceName, centeredAt: point)
        case .raster(let sourceName, let image):
            return commitImageLayerImport(image, sourceName: sourceName, centeredAt: point)
        }
    }

    @discardableResult
    func importLayerFiles(_ urls: [URL], centeredAt point: CGPoint? = nil) -> Bool {
        guard let urls = ImageEditorLayerFileImportPolicy.supportedURLs(from: urls) else {
            statusText = L10n.text("imageEditor.status.layerImportFailed")
            return false
        }
        if urls.count == 1, let url = urls.first {
            return importLayerFile(url, centeredAt: point)
        }

        var preparedImports: [ImageEditorPreparedLayerFileImport] = []
        preparedImports.reserveCapacity(urls.count)
        for url in urls {
            guard let prepared = prepareLayerFileImport(url) else { return false }
            preparedImports.append(prepared)
        }

        let frames = ImageEditorLayerFileImportPolicy.batchFrames(
            for: preparedImports.map(\.size),
            centeredAt: point ?? CGPoint(
                x: max(document.canvasSize.width, 1) / 2,
                y: max(document.canvasSize.height, 1) / 2
            )
        )
        guard frames.count == preparedImports.count else {
            statusText = L10n.text("imageEditor.status.layerImportFailed")
            return false
        }

        pushUndo()
        endPixelSelectionForImportedObject()
        let layers = zip(preparedImports, frames).map { prepared, frame in
            importedLayer(from: prepared, frame: frame)
        }
        document.layers.append(contentsOf: layers)
        selectImportedLayers(layers.map(\.id), primaryLayerID: layers.last?.id)
        appendHistory(L10n.text("imageEditor.history.layerBatchImport"))
        statusText = L10n.format("imageEditor.status.layersImported", layers.count)
        return true
    }

    private func prepareLayerFileImport(_ url: URL) -> ImageEditorPreparedLayerFileImport? {
        guard let kind = ImageEditorLayerFileImportPolicy.kind(for: url) else {
            statusText = L10n.text("imageEditor.status.layerImportFailed")
            return nil
        }

        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            statusText = L10n.text("imageEditor.status.layerImportFailed")
            return nil
        }

        switch kind {
        case .editableSVG:
            guard let data = try? Data(contentsOf: url),
                  let imported = XomoEditableSVGImporter.parse(data)
            else {
                statusText = L10n.text("imageEditor.status.editableSVGImportFailed")
                return nil
            }
            return .editableSVG(sourceName: url.lastPathComponent, imported: imported)
        case .rasterImage:
            guard let image = NSImage(contentsOf: url) else {
                statusText = L10n.text("imageEditor.status.layerImportFailed")
                return nil
            }
            let normalized = image.normalizedImportedBitmapImage()
            guard normalized.size.width > 0, normalized.size.height > 0 else {
                statusText = L10n.text("imageEditor.status.layerImportFailed")
                return nil
            }
            return .raster(sourceName: url.lastPathComponent, image: normalized)
        }
    }

    private func importedLayer(
        from prepared: ImageEditorPreparedLayerFileImport,
        frame: CGRect
    ) -> ImageEditorLayer {
        switch prepared {
        case .editableSVG(let sourceName, let imported):
            var layer = ImageEditorLayer.shape(
                name: cleanLayerName(from: sourceName),
                frame: frame,
                content: imported.content
            )
            layer.groupID = nil
            layer.isClippingMask = false
            return layer
        case .raster(let sourceName, let image):
            var layer = ImageEditorLayer.blank(
                name: L10n.format("imageEditor.layer.importedName", cleanLayerName(from: sourceName)),
                size: image.size
            )
            layer.image = image
            layer.frame = frame
            layer.opacity = 1
            layer.blendMode = .normal
            layer.groupID = nil
            layer.isClippingMask = false
            return layer
        }
    }

    private func selectImportedLayers(_ layerIDs: [UUID], primaryLayerID: UUID?) {
        document.selectedLayerID = primaryLayerID
        document.selectedLayerIDs = Set(layerIDs)
        isEditingLayerMask = false

        // Imported objects must own the next contextual Delete. Otherwise a
        // stale slice or hotspot selection can consume the key while the
        // visibly selected imported layer remains on the canvas.
        selectedHotspotID = nil
        if exportSettings.scope == .slice {
            exportSettings.scope = layerIDs.count > 1 ? .selectedLayers : .selectedLayer
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

        return commitEditableSVGImport(imported, sourceName: sourceName, centeredAt: point)
    }

    private func commitEditableSVGImport(
        _ imported: XomoEditableSVGImport,
        sourceName: String,
        centeredAt point: CGPoint?
    ) -> Bool {

        let cleanName = cleanLayerName(from: sourceName)
        pushUndo()
        endPixelSelectionForImportedObject()
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
        selectImportedLayers([layer.id], primaryLayerID: layer.id)
        appendHistory(L10n.text("imageEditor.history.editableSVGImport"))
        statusText = L10n.format("imageEditor.status.editableSVGImported", cleanName)
        return true
    }

    func chooseSmartObjectReplacementFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .webP]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = L10n.text("imageEditor.action.layerSmartObjectReplace")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                self.replaceSelectedSmartObjectContentsFile(url)
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
        if let archive = XomoLayerClipboardArchive.restoredCopy(
            from: pasteboard,
            offset: XomoLayerClipboardArchive.normalPasteOffset
        ) {
            return commitLayerClipboardArchive(
                archive,
                status: L10n.text("imageEditor.status.clipboardObjectsPasted")
            )
        }
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
        if let archive = XomoLayerClipboardArchive.restoredCopy(
            from: pasteboard,
            offset: .zero
        ) {
            return commitLayerClipboardArchive(
                archive,
                status: L10n.text("imageEditor.status.clipboardObjectsPastedInPlace")
            )
        }
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

    private func commitLayerClipboardArchive(
        _ archive: XomoRestoredLayerClipboardArchive,
        status: String
    ) -> Bool {
        guard !archive.layers.isEmpty,
              !archive.selectedRootIDs.isEmpty
        else { return false }
        pushUndo()
        endPixelSelectionForImportedObject()
        document.layers.append(contentsOf: archive.layers)
        normalizeLayerLinks()
        normalizeClippingMasks()
        selectImportedLayers(
            Array(archive.selectedRootIDs),
            primaryLayerID: archive.primaryRootID
        )
        appendHistory(L10n.text("imageEditor.history.clipboardPasteObjects"))
        statusText = status
        return true
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

        return commitImageLayerImport(
            normalized,
            sourceName: sourceName,
            historyTitle: historyTitle,
            importedStatus: importedStatus,
            frameOverride: frameOverride,
            centeredAt: point
        )
    }

    private func commitImageLayerImport(
        _ normalized: NSImage,
        sourceName: String,
        historyTitle: String? = nil,
        importedStatus: String? = nil,
        frameOverride: CGRect? = nil,
        centeredAt point: CGPoint? = nil
    ) -> Bool {

        pushUndo()
        endPixelSelectionForImportedObject()
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
        selectImportedLayers([layer.id], primaryLayerID: layer.id)
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
        selectImportedLayers([layer.id], primaryLayerID: layer.id)
        appendHistory(historyTitle ?? L10n.text("imageEditor.history.clipboardPasteIntoSelection"))
        statusText = importedStatus ?? L10n.format("imageEditor.status.layerImported", cleanLayerName(from: sourceName))
        return true
    }

    @discardableResult
    func replaceSelectedSmartObjectContentsFile(
        _ url: URL
    ) -> ImageEditorSmartObjectReplacementResult {
        guard ImageEditorEmbeddedSmartObjectFilePolicy.supports(url),
              let image = NSImage(contentsOf: url)
        else {
            statusText = L10n.text("imageEditor.status.layerSmartObjectReplaceFailed")
            return .failed
        }
        return replaceSelectedSmartObjectContents(
            image,
            sourceName: url.lastPathComponent
        )
    }

    @discardableResult
    func replaceSelectedSmartObjectContents(
        _ image: NSImage,
        sourceName: String
    ) -> ImageEditorSmartObjectReplacementResult {
        let sourceIDs = smartObjectReplacementTargetSourceIDs()
        guard !sourceIDs.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return .failed
        }

        let normalized = image.normalizedImportedBitmapImage()
        guard normalized.size.width > 0, normalized.size.height > 0 else {
            statusText = L10n.text("imageEditor.status.layerSmartObjectReplaceFailed")
            return .failed
        }

        let cleanSourceName = cleanLayerName(from: sourceName)
        let replacementData = normalized.qingtuPNGData()
        let replacementSourceIDs = sourceIDs.filter { sourceID in
            !smartObjectSourceMatchesReplacement(
                sourceID: sourceID,
                image: normalized,
                imageData: replacementData,
                sourceName: cleanSourceName
            )
        }
        guard !replacementSourceIDs.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerSmartObjectContentsUnchanged")
            return .unchanged
        }

        pushUndo()
        var replacedCount = 0
        for layerIndex in document.layers.indices {
            guard let content = document.layers[layerIndex].smartObjectContent,
                  replacementSourceIDs.contains(content.sourceID)
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
        return .changed
    }

    private func smartObjectSourceMatchesReplacement(
        sourceID: UUID,
        image: NSImage,
        imageData: Data?,
        sourceName: String
    ) -> Bool {
        guard let imageData else { return false }
        let instances = document.layers.filter { $0.smartObjectContent?.sourceID == sourceID }
        guard !instances.isEmpty else { return false }
        return instances.allSatisfy { layer in
            guard let content = layer.smartObjectContent,
                  content.sourceName == sourceName,
                  content.originalSize == image.size,
                  layer.image.size == image.size,
                  let currentData = layer.image.qingtuPNGData()
            else { return false }
            return currentData == imageData
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
