//
//  ImageEditorImport.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import UniformTypeIdentifiers

@MainActor
extension ImageEditorViewModel {
    func chooseImageLayerFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = L10n.text("imageEditor.action.layerImport")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                guard let image = NSImage(contentsOf: url) else {
                    self.statusText = L10n.text("imageEditor.status.layerImportFailed")
                    return
                }
                self.importImageLayer(image, sourceName: url.lastPathComponent)
            }
        }
    }

    func importImageLayer(_ image: NSImage, sourceName: String) {
        let normalized = image.normalizedBitmapImage()
        guard normalized.size.width > 0, normalized.size.height > 0 else {
            statusText = L10n.text("imageEditor.status.layerImportFailed")
            return
        }

        pushUndo()
        var layer = ImageEditorLayer.blank(
            name: L10n.format("imageEditor.layer.importedName", cleanLayerName(from: sourceName)),
            size: normalized.size
        )
        layer.image = normalized
        layer.frame = fittedImportFrame(for: normalized.size)
        layer.opacity = 1
        layer.blendMode = .normal
        layer.groupID = nil
        layer.isClippingMask = false
        document.layers.append(layer)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerImport"))
        statusText = L10n.format("imageEditor.status.layerImported", cleanLayerName(from: sourceName))
    }

    private func cleanLayerName(from sourceName: String) -> String {
        let cleanedSourceName = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = (cleanedSourceName as NSString).deletingPathExtension
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.text("imageEditor.layer.importedFallbackName") : trimmed
    }

    private func fittedImportFrame(for imageSize: CGSize) -> CGRect {
        let safeCanvasWidth = max(document.canvasSize.width, 1)
        let safeCanvasHeight = max(document.canvasSize.height, 1)
        let widthScale = safeCanvasWidth / max(imageSize.width, 1)
        let heightScale = safeCanvasHeight / max(imageSize.height, 1)
        let scale = min(1, widthScale, heightScale)
        let outputSize = CGSize(
            width: max(1, imageSize.width * scale),
            height: max(1, imageSize.height * scale)
        )
        return CGRect(
            x: (safeCanvasWidth - outputSize.width) / 2,
            y: (safeCanvasHeight - outputSize.height) / 2,
            width: outputSize.width,
            height: outputSize.height
        )
    }
}
