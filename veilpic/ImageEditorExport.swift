//
//  ImageEditorExport.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import ImageIO
import UniformTypeIdentifiers

enum ImageEditorExportFormat: String, CaseIterable, Identifiable {
    case png
    case jpeg
    case webp

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.export.format.\(rawValue)")
    }

    var filenameExtension: String {
        switch self {
        case .png:
            "png"
        case .jpeg:
            "jpg"
        case .webp:
            "webp"
        }
    }

    var contentType: UTType {
        switch self {
        case .png:
            .png
        case .jpeg:
            .jpeg
        case .webp:
            .webP
        }
    }
}

enum ImageEditorExportScope: String, CaseIterable, Identifiable {
    case composited
    case selectedLayer
    case selectedLayers

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.export.scope.\(rawValue)")
    }
}

struct ImageEditorExportSettings: Equatable {
    var format: ImageEditorExportFormat = .png
    var scope: ImageEditorExportScope = .composited
    var scale: Double = 1
    var quality: Double = 0.9

    var usesQuality: Bool {
        format != .png
    }
}

@MainActor
extension ImageEditorViewModel {
    var exportSizeText: String {
        let size = exportImage(for: exportSettings.scope).size.scaled(by: exportSettings.scale)
        return "\(Int(size.width.rounded())) x \(Int(size.height.rounded())) px"
    }

    var canExportSelectedLayer: Bool {
        guard let layer = document.selectedLayer else { return false }
        return !layer.isGroup && !layer.isAdjustment && !layer.isFilter
    }

    var canExportSelectedLayers: Bool {
        let selectedIDs = document.selectedLayerIDs
        guard !selectedIDs.isEmpty else { return false }
        return document.layers.contains { layer in
            document.shouldComposite(layer) && isLayer(layer, includedIn: selectedIDs)
        }
    }

    func openExportPanel() {
        if exportSettings.scope == .selectedLayer, !canExportSelectedLayer {
            exportSettings.scope = .composited
        }
        if exportSettings.scope == .selectedLayers, !canExportSelectedLayers {
            exportSettings.scope = .composited
        }
        isExportSheetPresented = true
    }

    func exportCompositedImage() {
        openExportPanel()
    }

    func exportData(settings: ImageEditorExportSettings) -> Data? {
        let image = exportImage(for: normalizedExportSettings(settings).scope)
        let scaled = image.scaled(by: settings.scale)
        switch settings.format {
        case .png:
            return scaled.qingtuPNGData()
        case .jpeg:
            return scaled.flattened(on: .white).bitmapData(type: .jpeg, quality: settings.quality)
        case .webp:
            return scaled.bitmapData(typeIdentifier: UTType.webP.identifier, quality: settings.quality)
        }
    }

    func runExport() {
        let settings = normalizedExportSettings(exportSettings)
        exportSettings = settings

        guard settings.format != .webp || NSImage.canWriteImage(typeIdentifier: UTType.webP.identifier) else {
            statusText = L10n.text("imageEditor.status.exportWebPUnsupported")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [settings.format.contentType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = exportFilename(settings: settings)
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                guard let data = self.exportData(settings: settings) else {
                    self.statusText = L10n.text("imageEditor.status.exportFailed")
                    return
                }
                do {
                    try data.write(to: url, options: .atomic)
                    self.statusText = L10n.format("imageEditor.status.exported", url.lastPathComponent)
                    self.isExportSheetPresented = false
                } catch {
                    self.statusText = L10n.format("imageEditor.status.exportFailedWithReason", error.localizedDescription)
                }
            }
        }
    }

    private func normalizedExportSettings(_ settings: ImageEditorExportSettings) -> ImageEditorExportSettings {
        var normalized = settings
        normalized.scale = min(4, max(0.25, normalized.scale))
        normalized.quality = min(1, max(0.1, normalized.quality))
        if normalized.scope == .selectedLayer, !canExportSelectedLayer {
            normalized.scope = .composited
        }
        if normalized.scope == .selectedLayers, !canExportSelectedLayers {
            normalized.scope = .composited
        }
        return normalized
    }

    private func exportImage(for scope: ImageEditorExportScope) -> NSImage {
        switch scope {
        case .composited:
            document.compositedImage
        case .selectedLayer:
            selectedLayerExportImage() ?? document.compositedImage
        case .selectedLayers:
            selectedLayersExportImage() ?? document.compositedImage
        }
    }

    private func selectedLayerExportImage() -> NSImage? {
        guard let index = document.selectedLayerIndex else { return nil }
        let layer = document.layers[index]
        guard !layer.isGroup, !layer.isAdjustment, !layer.isFilter else { return nil }

        return NSImage.rendered(size: document.canvasSize) { _ in
            if layer.isClippingMask,
               let clippedImage = document.clippedCompositingImage(forLayerAt: index) {
                clippedImage.draw(
                    in: CGRect(origin: .zero, size: document.canvasSize),
                    from: CGRect(origin: .zero, size: document.canvasSize),
                    operation: .sourceOver,
                    fraction: layer.opacity
                )
            } else {
                let image = layer.renderedCompositingImage(globalLightAngle: document.globalLightAngle)
                image.draw(
                    in: layer.renderedCompositingFrame(globalLightAngle: document.globalLightAngle),
                    from: CGRect(origin: .zero, size: image.size),
                    operation: .sourceOver,
                    fraction: layer.opacity
                )
            }
        }
    }

    private func selectedLayersExportImage() -> NSImage? {
        guard canExportSelectedLayers else { return nil }
        return document.compositedImage(includingOnly: document.selectedLayerIDs)
    }

    private func exportFilename(settings: ImageEditorExportSettings) -> String {
        let base = (document.sourceName as NSString).deletingPathExtension
        let cleaned = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix: String
        switch settings.scope {
        case .composited:
            suffix = "edited"
        case .selectedLayer:
            suffix = "layer"
        case .selectedLayers:
            suffix = "selected-layers"
        }
        return "\((cleaned.isEmpty ? "image" : cleaned))-\(suffix).\(settings.format.filenameExtension)"
    }

    private func isLayer(_ layer: ImageEditorLayer, includedIn includedLayerIDs: Set<UUID>) -> Bool {
        includedLayerIDs.contains(layer.id)
            || document.ancestorGroups(for: layer).contains { includedLayerIDs.contains($0.id) }
    }
}

private extension CGSize {
    func scaled(by scale: Double) -> CGSize {
        CGSize(
            width: max(1, width * CGFloat(scale)),
            height: max(1, height * CGFloat(scale))
        )
    }
}

private extension NSImage {
    static func canWriteImage(typeIdentifier: String) -> Bool {
        let writableTypes = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return writableTypes.contains(typeIdentifier)
    }

    func scaled(by scale: Double) -> NSImage {
        guard scale != 1 else { return self }
        let outputSize = size.scaled(by: scale)
        return NSImage.rendered(size: outputSize) { _ in
            draw(
                in: CGRect(origin: .zero, size: outputSize),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
        } ?? self
    }

    func flattened(on color: NSColor) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
            draw(
                in: rect,
                from: CGRect(origin: .zero, size: size),
                operation: .sourceOver,
                fraction: 1
            )
        } ?? self
    }

    func bitmapData(type: NSBitmapImageRep.FileType, quality: Double) -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation)
        else {
            return nil
        }
        return bitmap.representation(
            using: type,
            properties: [.compressionFactor: min(1, max(0.1, quality))]
        )
    }

    func bitmapData(typeIdentifier: String, quality: Double) -> Data? {
        guard Self.canWriteImage(typeIdentifier: typeIdentifier),
              let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, typeIdentifier as CFString, 1, nil) else {
            return nil
        }

        CGImageDestinationAddImage(
            destination,
            cgImage,
            [kCGImageDestinationLossyCompressionQuality: min(1, max(0.1, quality))] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }
}
