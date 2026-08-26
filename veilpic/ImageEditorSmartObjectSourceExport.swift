import AppKit
import UniformTypeIdentifiers

enum ImageEditorSmartObjectSourcePNGExportPolicy {
    static func filename(sourceName: String) -> String {
        let lastComponent = (sourceName as NSString).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = (lastComponent as NSString).deletingPathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(baseName.isEmpty ? "smart-object" : baseName).png"
    }

    static func supports(_ url: URL) -> Bool {
        url.isFileURL && url.pathExtension.lowercased() == "png"
    }
}

@MainActor
extension ImageEditorViewModel {
    var canExportSelectedSmartObjectSourcePNG: Bool {
        selectedSmartObjectSourceExportLayer() != nil
    }

    func canExportSmartObjectSourcePNG(selectedIDs: Set<UUID>) -> Bool {
        smartObjectSourceExportLayer(selectedIDs: selectedIDs) != nil
    }

    func selectedSmartObjectSourcePNGData() -> Data? {
        selectedSmartObjectSourceExportLayer()?.image.qingtuPNGData()
    }

    func selectedSmartObjectSourcePNGFilename() -> String? {
        guard let layer = selectedSmartObjectSourceExportLayer(),
              let content = layer.smartObjectContent
        else { return nil }
        return ImageEditorSmartObjectSourcePNGExportPolicy.filename(
            sourceName: content.sourceName
        )
    }

    func chooseSmartObjectSourcePNGDestination() {
        guard let data = selectedSmartObjectSourcePNGData(),
              let filename = selectedSmartObjectSourcePNGFilename()
        else {
            statusText = L10n.text("imageEditor.status.smartObjectSourcePNGExportFailed")
            return
        }
        chooseSmartObjectSourcePNGDestination(data: data, filename: filename)
    }

    func chooseSmartObjectSourcePNGDestination(
        data: Data,
        filename: String
    ) {
        let originatingWindow = NSApp.keyWindow
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = filename
        panel.prompt = L10n.text("imageEditor.action.smartObjectSourcePNGExport")
        panel.begin { [weak self] response in
            Task { @MainActor in
                defer {
                    ImageEditorFilePanelKeyboardFocusRestorer.restore(to: originatingWindow)
                }
                guard let self, response == .OK, let url = panel.url else { return }
                self.writeSmartObjectSourcePNG(
                    data,
                    to: url
                )
            }
        }
    }

    @discardableResult
    func writeSelectedSmartObjectSourcePNG(
        to url: URL,
        dataWriter: (Data, URL) throws -> Void = { data, destination in
            try data.write(to: destination, options: .atomic)
        }
    ) -> Bool {
        guard let data = selectedSmartObjectSourcePNGData() else {
            statusText = L10n.text("imageEditor.status.smartObjectSourcePNGExportFailed")
            return false
        }
        return writeSmartObjectSourcePNG(data, to: url, dataWriter: dataWriter)
    }

    @discardableResult
    func writeSmartObjectSourcePNG(
        _ data: Data,
        to url: URL,
        dataWriter: (Data, URL) throws -> Void = { data, destination in
            try data.write(to: destination, options: .atomic)
        }
    ) -> Bool {
        guard ImageEditorSmartObjectSourcePNGExportPolicy.supports(url) else {
            statusText = L10n.text("imageEditor.status.smartObjectSourcePNGExportFailed")
            return false
        }
        let destination = url.standardizedFileURL
        do {
            try dataWriter(data, destination)
            statusText = L10n.format(
                "imageEditor.status.smartObjectSourcePNGExported",
                destination.lastPathComponent
            )
            return true
        } catch {
            statusText = L10n.format(
                "imageEditor.status.smartObjectSourcePNGExportFailedWithReason",
                error.localizedDescription
            )
            return false
        }
    }

    private func selectedSmartObjectSourceExportLayer() -> ImageEditorLayer? {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return smartObjectSourceExportLayer(selectedIDs: selectedIDs)
    }

    private func smartObjectSourceExportLayer(
        selectedIDs: Set<UUID>
    ) -> ImageEditorLayer? {
        guard selectedIDs.count == 1, let selectedID = selectedIDs.first else { return nil }
        return document.layers.first { layer in
            layer.id == selectedID && layer.isSmartObject
        }
    }
}
