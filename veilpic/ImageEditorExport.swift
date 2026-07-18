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
    case pdf
    case svg
    case psd

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
        case .pdf:
            "pdf"
        case .svg:
            "svg"
        case .psd:
            "psd"
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
        case .pdf:
            .pdf
        case .svg:
            UTType(filenameExtension: "svg") ?? .xml
        case .psd:
            ImageEditorPSDCodec.contentType
        }
    }
}

enum ImageEditorExportScope: String, CaseIterable, Identifiable {
    case composited
    case selectedLayer
    case selectedLayers
    case selection
    case slice

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.export.scope.\(rawValue)")
    }
}

enum ImageEditorExportNamingRule: String, CaseIterable, Identifiable {
    case sourceName
    case sourceAndScope
    case sourceScopeAndScale

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.export.namingRule.\(rawValue)")
    }
}

struct ImageEditorExportSettings: Equatable {
    static let batchScalePresets: [Double] = [1, 2, 3]

    var format: ImageEditorExportFormat = .png
    var scope: ImageEditorExportScope = .composited
    var sliceID: UUID?
    var scale: Double = 1
    var batchScales: Set<Double> = []
    var namingRule: ImageEditorExportNamingRule = .sourceScopeAndScale
    var quality: Double = 0.9

    var usesQuality: Bool {
        format == .jpeg || format == .webp
    }

    var usesScale: Bool {
        switch format {
        case .png, .jpeg, .webp:
            true
        case .pdf, .svg, .psd:
            false
        }
    }
}

@MainActor
extension ImageEditorViewModel {
    var exportSizeText: String {
        let scale = exportSettings.usesScale ? exportSettings.scale : 1
        let size = exportImage(for: exportSettings.scope, sliceID: exportSettings.sliceID).size.scaled(by: scale)
        return "\(Int(size.width.rounded())) x \(Int(size.height.rounded())) px"
    }

    var canExportNamedSlice: Bool {
        guard !document.slices.isEmpty else { return false }
        guard let sliceID = exportSettings.sliceID else { return true }
        return slice(with: sliceID) != nil
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

    /// Returns the narrowest valid layer export scope for the current layer
    /// selection. A single editable layer keeps its own scope; groups and
    /// multi-selection use the composite of the selected layer subtree.
    var selectedLayersExportScope: ImageEditorExportScope? {
        guard !document.selectedLayerIDs.isEmpty else { return nil }
        if document.selectedLayerIDs.count == 1, canExportSelectedLayer {
            return .selectedLayer
        }
        return canExportSelectedLayers ? .selectedLayers : nil
    }

    var canExportSelection: Bool {
        selectionExportBounds != nil
    }

    var canExportSVG: Bool {
        svgExportLayers != nil
    }

    func openExportPanel() {
        if exportSettings.format == .svg, !canExportSVG {
            exportSettings.format = .png
        }
        if exportSettings.format == .svg {
            exportSettings.scope = .composited
            exportSettings.scale = 1
        }
        if exportSettings.scope == .selectedLayer, !canExportSelectedLayer {
            exportSettings.scope = .composited
        }
        if exportSettings.scope == .selectedLayers, !canExportSelectedLayers {
            exportSettings.scope = .composited
        }
        if exportSettings.scope == .selection, !canExportSelection {
            exportSettings.scope = .composited
        }
        if exportSettings.scope == .slice {
            if let sliceID = exportSettings.sliceID, slice(with: sliceID) != nil {
                // Keep the current named slice.
            } else if let firstSlice = document.slices.first {
                exportSettings.sliceID = firstSlice.id
            } else {
                exportSettings.scope = .composited
                exportSettings.sliceID = nil
            }
        }
        isExportSheetPresented = true
    }

    func exportCompositedImage() {
        openExportPanel()
    }

    func exportData(settings: ImageEditorExportSettings) -> Data? {
        let normalized = normalizedExportSettings(settings)
        let image = exportImage(for: normalized.scope, sliceID: normalized.sliceID)
        let scaled = image.scaled(by: normalized.scale)
        switch normalized.format {
        case .png:
            return scaled.qingtuPNGData()
        case .jpeg:
            return scaled.flattened(on: .white).bitmapData(type: .jpeg, quality: normalized.quality)
        case .webp:
            return scaled.bitmapData(typeIdentifier: UTType.webP.identifier, quality: normalized.quality)
        case .pdf:
            return image.pdfData()
        case .svg:
            return svgData()
        case .psd:
            return try? ImageEditorPSDCodec.encode(document: document)
        }
    }

    func exportFilenames(settings: ImageEditorExportSettings) -> [String] {
        let normalized = normalizedExportSettings(settings)
        let scales = exportScales(for: normalized)
        return scales.map { scale in
            exportFilename(
                settings: normalized,
                scale: scale,
                includesScaleSuffix: scales.count > 1
            )
        }
    }

    func runExport() {
        let settings = normalizedExportSettings(exportSettings)
        exportSettings = settings

        guard settings.format != .webp || NSImage.canWriteImage(typeIdentifier: UTType.webP.identifier) else {
            statusText = L10n.text("imageEditor.status.exportWebPUnsupported")
            return
        }
        guard settings.format != .svg || canExportSVG else {
            statusText = L10n.text("imageEditor.status.exportSVGRequiresVector")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [settings.format.contentType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = exportFilename(
            settings: settings,
            scale: settings.scale,
            includesScaleSuffix: false
        )
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                do {
                    let scales = self.exportScales(for: settings)
                    for scale in scales {
                        var variantSettings = settings
                        variantSettings.scale = scale
                        variantSettings.batchScales = []
                        guard let data = self.exportData(settings: variantSettings) else {
                            self.statusText = L10n.text("imageEditor.status.exportFailed")
                            return
                        }
                        let destination = scales.count == 1
                            ? url
                            : self.batchExportURL(from: url, scale: scale, format: settings.format)
                        try data.write(to: destination, options: .atomic)
                    }
                    self.statusText = scales.count == 1
                        ? L10n.format("imageEditor.status.exported", url.lastPathComponent)
                        : L10n.format("imageEditor.status.exportedBatch", scales.count, url.deletingLastPathComponent().lastPathComponent)
                    self.isExportSheetPresented = false
                } catch {
                    self.statusText = L10n.format("imageEditor.status.exportFailedWithReason", error.localizedDescription)
                }
            }
        }
    }

    private func normalizedExportSettings(_ settings: ImageEditorExportSettings) -> ImageEditorExportSettings {
        var normalized = settings
        if normalized.format == .psd || normalized.format == .svg {
            normalized.scope = .composited
            normalized.scale = 1
        }
        if normalized.format == .pdf {
            normalized.scale = 1
        }
        normalized.scale = min(4, max(0.25, normalized.scale))
        normalized.batchScales = Set(normalized.batchScales.filter { scale in
            ImageEditorExportSettings.batchScalePresets.contains(scale)
        })
        normalized.quality = min(1, max(0.1, normalized.quality))
        if normalized.scope == .selectedLayer, !canExportSelectedLayer {
            normalized.scope = .composited
        }
        if normalized.scope == .selectedLayers, !canExportSelectedLayers {
            normalized.scope = .composited
        }
        if normalized.scope == .selection, !canExportSelection {
            normalized.scope = .composited
        }
        if normalized.scope == .slice {
            if let sliceID = normalized.sliceID, slice(with: sliceID) != nil {
                // Keep the requested named slice.
            } else if let firstSlice = document.slices.first {
                normalized.sliceID = firstSlice.id
            } else {
                normalized.scope = .composited
                normalized.sliceID = nil
            }
        }
        return normalized
    }

    private func exportImage(for scope: ImageEditorExportScope, sliceID: UUID? = nil) -> NSImage {
        switch scope {
        case .composited:
            document.compositedImage
        case .selectedLayer:
            selectedLayerExportImage() ?? document.compositedImage
        case .selectedLayers:
            selectedLayersExportImage() ?? document.compositedImage
        case .selection:
            selectedSelectionExportImage() ?? document.compositedImage
        case .slice:
            namedSliceExportImage(for: sliceID) ?? document.compositedImage
        }
    }

    private func namedSliceExportImage(for id: UUID?) -> NSImage? {
        guard let id,
              let slice = slice(with: id),
              let image = document.compositedImage.cropped(to: slice.frame)
        else { return nil }
        return image
    }

    private var selectionExportBounds: CGRect? {
        guard let selection = document.selection else { return nil }
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        let candidate = selection.isInverted ? canvasBounds : selection.bounds.standardized
        let bounded = candidate.intersection(canvasBounds).integral.intersection(canvasBounds)
        guard bounded.width > 0, bounded.height > 0 else { return nil }
        return bounded
    }

    private func selectedSelectionExportImage() -> NSImage? {
        guard let selection = document.selection,
              let bounds = selectionExportBounds,
              let composited = document.compositedImage.cropped(to: bounds),
              let mask = selectionExportMask(for: selection)?.cropped(to: bounds)
        else { return nil }

        return NSImage.rendered(size: bounds.size) { _ in
            composited.draw(
                in: CGRect(origin: .zero, size: bounds.size),
                from: CGRect(origin: .zero, size: bounds.size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: CGRect(origin: .zero, size: bounds.size),
                from: CGRect(origin: .zero, size: bounds.size),
                operation: .destinationIn,
                fraction: 1
            )
        }
    }

    private func selectionExportMask(for selection: ImageEditorSelection) -> NSImage? {
        if let rasterMask = selection.rasterMask {
            return NSImage.selectionMaskImage(
                rasterMask,
                inverted: selection.isInverted,
                targetSize: document.canvasSize
            )
        }

        return NSImage.rendered(size: document.canvasSize) { rect in
            if selection.isInverted {
                NSColor.white.setFill()
                rect.fill()
                NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: document.canvasSize.height) {
                    guard let context = NSGraphicsContext.current?.cgContext else { return }
                    context.saveGState()
                    context.setBlendMode(.clear)
                    NSColor.clear.setFill()
                    selection.path().fill()
                    context.restoreGState()
                }
            } else {
                NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: document.canvasSize.height) {
                    NSColor.white.setFill()
                    selection.path().fill()
                }
            }
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

    private func exportScales(for settings: ImageEditorExportSettings) -> [Double] {
        guard settings.usesScale else { return [1] }
        return Set([settings.scale] + settings.batchScales).sorted()
    }

    private func exportFilename(
        settings: ImageEditorExportSettings,
        scale: Double,
        includesScaleSuffix: Bool
    ) -> String {
        let base = (document.sourceName as NSString).deletingPathExtension
        let cleaned = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceName = cleaned.isEmpty ? "image" : cleaned
        let scopeSuffix: String
        switch settings.scope {
        case .composited:
            scopeSuffix = "edited"
        case .selectedLayer:
            scopeSuffix = "layer"
        case .selectedLayers:
            scopeSuffix = "selected-layers"
        case .selection:
            scopeSuffix = "selection"
        case .slice:
            scopeSuffix = "slice"
        }
        let name: String
        switch settings.namingRule {
        case .sourceName:
            name = sourceName
        case .sourceAndScope, .sourceScopeAndScale:
            name = "\(sourceName)-\(scopeSuffix)"
        }
        let scaleSuffix = includesScaleSuffix && settings.usesScale ? "@\(exportScaleLabel(scale))" : ""
        return "\(name)\(scaleSuffix).\(settings.format.filenameExtension)"
    }

    private func batchExportURL(
        from url: URL,
        scale: Double,
        format: ImageEditorExportFormat
    ) -> URL {
        let baseName = (url.lastPathComponent as NSString).deletingPathExtension
        let filename = "\(baseName)@\(exportScaleLabel(scale)).\(format.filenameExtension)"
        return url.deletingLastPathComponent().appendingPathComponent(filename)
    }

    private func exportScaleLabel(_ scale: Double) -> String {
        scale.rounded() == scale
            ? "\(Int(scale))x"
            : "\(String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), scale))x"
    }

    private func isLayer(_ layer: ImageEditorLayer, includedIn includedLayerIDs: Set<UUID>) -> Bool {
        includedLayerIDs.contains(layer.id)
            || document.ancestorGroups(for: layer).contains { includedLayerIDs.contains($0.id) }
    }

    private var svgExportLayers: [ImageEditorLayer]? {
        let visibleLayers = document.layers.filter(document.shouldComposite)
        for layer in visibleLayers {
            guard canSerializeAsSVG(layer) else { return nil }
        }
        return visibleLayers.filter { layer in
            switch layer.kind {
            case .text, .shape:
                true
            default:
                false
            }
        }
    }

    private func canSerializeAsSVG(_ layer: ImageEditorLayer) -> Bool {
        guard layer.blendMode == .normal,
              layer.opacity > 0,
              layer.fillOpacity == 1,
              !layer.style.hasEffects,
              layer.mask == nil,
              layer.vectorMask == nil,
              !layer.isClippingMask,
              layer.smartFilters.isEmpty,
              layer.blendIfSourceBlack == 0,
              layer.blendIfSourceWhite == 1,
              layer.blendIfUnderlyingBlack == 0,
              layer.blendIfUnderlyingWhite == 1
        else { return false }

        switch layer.kind {
        case .text, .shape:
            return true
        case .pixel:
            return layer.image.nonTransparentPixelBounds() == nil
        default:
            return false
        }
    }

    private func svgData() -> Data? {
        guard let layers = svgExportLayers else { return nil }
        let size = document.canvasSize
        var elements: [String] = []
        elements.reserveCapacity(layers.count)
        for layer in layers {
            switch layer.kind {
            case let .shape(content):
                elements.append(svgShape(content, layer: layer))
            case let .text(content):
                elements.append(svgText(content, layer: layer))
            default:
                continue
            }
        }
        let source = [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(svgNumber(size.width))\" height=\"\(svgNumber(size.height))\" viewBox=\"0 0 \(svgNumber(size.width)) \(svgNumber(size.height))\">",
            elements.joined(separator: "\n"),
            "</svg>"
        ].joined(separator: "\n")
        return source.data(using: .utf8)
    }

    private func svgShape(_ content: ImageEditorShapeContent, layer: ImageEditorLayer) -> String {
        let normalized = content.normalized(size: layer.image.size)
        let attributes = svgPaintAttributes(content: normalized, layer: layer)
        switch normalized.kind {
        case .rectangle:
            let inset = normalized.strokeWidth / 2
            let frame = layer.frame.insetBy(dx: inset, dy: inset)
            return "<rect x=\"\(svgNumber(frame.minX))\" y=\"\(svgNumber(frame.minY))\" width=\"\(svgNumber(frame.width))\" height=\"\(svgNumber(frame.height))\" \(attributes) />"
        case .ellipse:
            return "<ellipse cx=\"\(svgNumber(layer.frame.midX))\" cy=\"\(svgNumber(layer.frame.midY))\" rx=\"\(svgNumber(max(0, layer.frame.width - normalized.strokeWidth) / 2))\" ry=\"\(svgNumber(max(0, layer.frame.height - normalized.strokeWidth) / 2))\" \(attributes) />"
        case .path:
            return "<path d=\"\(svgPathData(content: normalized, layer: layer))\" \(attributes) />"
        }
    }

    private func svgText(_ content: ImageEditorTextContent, layer: ImageEditorLayer) -> String {
        let color = svgColor(content.color)
        let fontStyle = content.isItalic ? " font-style=\"italic\"" : ""
        let fontWeight = content.isBold ? "bold" : "600"
        let anchor: String
        let x: CGFloat
        switch content.alignment {
        case .left:
            anchor = "start"
            x = layer.frame.minX + content.point.x + ImageEditorTextContent.drawingPadding
        case .center:
            anchor = "middle"
            x = layer.frame.minX + max(content.boxWidth, layer.frame.width) / 2
        case .right:
            anchor = "end"
            x = layer.frame.maxX - ImageEditorTextContent.drawingPadding
        case .justified:
            anchor = "start"
            x = layer.frame.minX + content.point.x + ImageEditorTextContent.drawingPadding + content.leftIndent
        }
        let y = layer.frame.minY + content.point.y + content.fontSize
        let lineHeight = content.fontSize + max(0, content.lineSpacing)
        let lines = content.text.components(separatedBy: .newlines)
        let tspans = lines.enumerated().map { index, line in
            let verticalOffset = index == 0 ? "0" : svgNumber(lineHeight)
            return "<tspan x=\"\(svgNumber(x))\" dy=\"\(verticalOffset)\">\(svgEscaped(line))</tspan>"
        }.joined()
        return "<text x=\"\(svgNumber(x))\" y=\"\(svgNumber(y))\" text-anchor=\"\(anchor)\" font-family=\"-apple-system, BlinkMacSystemFont, sans-serif\" font-size=\"\(svgNumber(content.fontSize))\" font-weight=\"\(fontWeight)\" letter-spacing=\"\(svgNumber(content.characterSpacing))\" fill=\"\(color.hex)\" fill-opacity=\"\(svgNumber(color.alpha * layer.opacity))\"\(fontStyle)>\(tspans)</text>"
    }

    private func svgPathData(content: ImageEditorShapeContent, layer: ImageEditorLayer) -> String {
        content.allEditablePathSubpaths.compactMap { anchors in
            guard let first = anchors.first else { return nil }
            var commands = ["M \(svgPoint(first.point, layer: layer))"]
            for index in anchors.indices.dropFirst() {
                let previous = anchors[index - 1]
                let current = anchors[index]
                if previous.outControl != nil || current.inControl != nil {
                    commands.append("C \(svgPoint(previous.outControl ?? previous.point, layer: layer)) \(svgPoint(current.inControl ?? current.point, layer: layer)) \(svgPoint(current.point, layer: layer))")
                } else {
                    commands.append("L \(svgPoint(current.point, layer: layer))")
                }
            }
            if content.isPathClosed, anchors.count > 2 {
                let last = anchors[anchors.count - 1]
                if last.outControl != nil || first.inControl != nil {
                    commands.append("C \(svgPoint(last.outControl ?? last.point, layer: layer)) \(svgPoint(first.inControl ?? first.point, layer: layer)) \(svgPoint(first.point, layer: layer))")
                }
                commands.append("Z")
            }
            return commands.joined(separator: " ")
        }.joined(separator: " ")
    }

    private func svgPaintAttributes(content: ImageEditorShapeContent, layer: ImageEditorLayer) -> String {
        let fill = svgColor(content.fillColor)
        let stroke = svgColor(content.strokeColor)
        let fillValue = content.kind == .path && !content.isPathClosed ? "none" : fill.hex
        return "fill=\"\(fillValue)\" fill-opacity=\"\(svgNumber(fill.alpha * content.fillOpacity * layer.opacity))\" stroke=\"\(stroke.hex)\" stroke-opacity=\"\(svgNumber(stroke.alpha * content.strokeOpacity * layer.opacity))\" stroke-width=\"\(svgNumber(content.strokeWidth))\" stroke-linejoin=\"round\" stroke-linecap=\"round\""
    }

    private func svgPoint(_ point: CGPoint, layer: ImageEditorLayer) -> String {
        let x = layer.frame.minX + point.x / max(layer.image.size.width, 1) * layer.frame.width
        let y = layer.frame.minY + point.y / max(layer.image.size.height, 1) * layer.frame.height
        return "\(svgNumber(x)) \(svgNumber(y))"
    }

    private func svgColor(_ color: NSColor) -> (hex: String, alpha: CGFloat) {
        let converted = color.usingColorSpace(.sRGB) ?? color
        let red = Int((converted.redComponent * 255).rounded())
        let green = Int((converted.greenComponent * 255).rounded())
        let blue = Int((converted.blueComponent * 255).rounded())
        return (String(format: "#%02X%02X%02X", red, green, blue), converted.alphaComponent)
    }

    private func svgNumber(_ value: CGFloat) -> String {
        String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
            .replacingOccurrences(of: ".000", with: "")
    }

    private func svgEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
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

    func pdfData() -> Data? {
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output),
              size.width > 0,
              size.height > 0
        else { return nil }
        var mediaBox = CGRect(origin: .zero, size: size)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
        context.beginPDFPage(nil)
        context.saveGState()
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        draw(
            in: CGRect(origin: .zero, size: size),
            from: CGRect(origin: .zero, size: size),
            operation: .sourceOver,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
        context.endPDFPage()
        context.closePDF()
        return output as Data
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
