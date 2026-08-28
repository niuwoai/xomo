//
//  ImageEditorExport.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import ImageIO
import UniformTypeIdentifiers

private typealias ImageEditorSVGExportPlan = (
    layers: [ImageEditorLayer],
    groupIDs: Set<UUID>
)

enum ImageEditorExportFormat: String, CaseIterable, Identifiable, Codable, Sendable {
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

    var supportsSliceExportPreset: Bool {
        Self.sliceExportPresetFormats.contains(self)
    }

    static let sliceExportPresetFormats: [Self] = [.png, .jpeg, .pdf]
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

enum ImageEditorLayerCompExportScope: Equatable {
    case all
    case favorites
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
    static let supportedScaleRange = 0.25...4.0

    var format: ImageEditorExportFormat = .png
    var scope: ImageEditorExportScope = .composited
    var sliceID: UUID?
    var scale: Double = 1
    var batchScales: Set<Double> = []
    var namingRule: ImageEditorExportNamingRule = .sourceScopeAndScale
    var quality: Double = 0.9
    var filenameSuffix: String = ""
    var sliceConflictPolicy: ImageEditorSliceExportConflictPolicy = .abort

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

struct ImageEditorSliceExportVariant: Equatable {
    let sliceID: UUID
    let filename: String
    let settings: ImageEditorExportSettings
}

struct ImageEditorSliceExportArtifact {
    let variant: ImageEditorSliceExportVariant
    let data: Data
}

struct ImageEditorLayerCompExportVariant: Equatable {
    let layerCompID: UUID
    let filename: String
}

struct ImageEditorLayerCompExportArtifact {
    let variant: ImageEditorLayerCompExportVariant
    let data: Data
}

enum ImageEditorSliceExportConflictPolicy: String, CaseIterable, Identifiable {
    case abort
    case skipExisting

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.export.sliceConflictPolicy.\(rawValue)")
    }

    struct Resolution {
        let deliverablePlan: [ImageEditorSliceExportVariant]
        let conflictingFilenames: [String]
    }

    static func conflictingFilenames(
        in plan: [ImageEditorSliceExportVariant],
        fileExists: (String) -> Bool
    ) -> [String] {
        plan.map(\.filename).filter(fileExists)
    }

    static func resolve(
        plan: [ImageEditorSliceExportVariant],
        policy: Self,
        fileExists: (String) -> Bool
    ) -> Resolution {
        var deliverablePlan: [ImageEditorSliceExportVariant] = []
        var conflictingFilenames: [String] = []
        for variant in plan {
            if fileExists(variant.filename) {
                conflictingFilenames.append(variant.filename)
            } else {
                deliverablePlan.append(variant)
            }
        }
        if policy == .abort, !conflictingFilenames.isEmpty {
            deliverablePlan = []
        }
        return Resolution(
            deliverablePlan: deliverablePlan,
            conflictingFilenames: conflictingFilenames
        )
    }
}

@MainActor
extension ImageEditorViewModel {
    static let layerCompExportFormats: [ImageEditorExportFormat] = [
        .png,
        .jpeg,
        .webp,
        .pdf,
        .psd
    ]

    var canExportLayerComps: Bool {
        !document.layerComps.isEmpty
    }

    var canExportFavoriteLayerComps: Bool {
        document.layerComps.contains { $0.isFavorite }
    }

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
        svgExportPlan != nil
    }

    var canCopySelectedLayersAsSVG: Bool {
        selectedLayersSVGExportPlan != nil
    }

    func openExportPanel() {
        isPreviewSheetPresented = false
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

    func openPreviewPanel() {
        isExportSheetPresented = false
        isPreviewSheetPresented = true
    }

    func exportCompositedImage() {
        openExportPanel()
    }

    func quickExportPNG() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = quickExportPNGFilename()
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                self.writeQuickExportPNG(to: url)
            }
        }
    }

    func quickExportPNGData() -> Data? {
        exportData(settings: quickExportPNGSettings)
    }

    func quickExportPNGFilename() -> String {
        exportFilenames(settings: quickExportPNGSettings).first ?? "image.png"
    }

    @discardableResult
    func copyQuickExportPNG(to pasteboard: NSPasteboard = .general) -> Bool {
        guard let data = quickExportPNGData(),
              let image = NSImage(data: data)
        else {
            statusText = L10n.text("imageEditor.status.copyQuickExportPNGFailed")
            return false
        }
        let didCopy = ClipboardImageWriter.copyPNGData(
            data,
            image: image,
            preferredFileName: quickExportPNGFilename(),
            to: pasteboard
        )
        statusText = L10n.text(
            didCopy
                ? "imageEditor.status.copyQuickExportPNG"
                : "imageEditor.status.copyQuickExportPNGFailed"
        )
        return didCopy
    }

    @discardableResult
    func copySelectedLayersAsSVG(to pasteboard: NSPasteboard = .general) -> Bool {
        guard let data = selectedLayersSVGData() else {
            statusText = L10n.text("imageEditor.status.copySelectedLayersAsSVGFailed")
            return false
        }
        let baseName = (document.sourceName as NSString).deletingPathExtension
        let preferredFileName = "\(baseName.isEmpty ? "image" : baseName)-selected.svg"
        let didCopy = ClipboardImageWriter.copySVGData(
            data,
            preferredFileName: preferredFileName,
            to: pasteboard
        )
        statusText = L10n.text(
            didCopy
                ? "imageEditor.status.copySelectedLayersAsSVG"
                : "imageEditor.status.copySelectedLayersAsSVGFailed"
        )
        return didCopy
    }

    func selectedLayersSVGData() -> Data? {
        guard let plan = selectedLayersSVGExportPlan,
              let bounds = plan.layers
                .map(\.frame)
                .map(\.standardized)
                .filter({ !$0.isEmpty && !$0.isNull && !$0.isInfinite })
                .reduce(nil, { result, frame in result?.union(frame) ?? frame })
        else { return nil }
        return svgData(plan: plan, viewport: bounds)
    }

    @discardableResult
    func writeQuickExportPNG(
        to url: URL,
        dataWriter: (Data, URL) throws -> Void = { data, destination in
            try data.write(to: destination, options: .atomic)
        }
    ) -> Bool {
        guard let data = quickExportPNGData() else {
            statusText = L10n.text("imageEditor.status.exportFailed")
            return false
        }
        let standardizedURL = url.standardizedFileURL
        do {
            try dataWriter(data, standardizedURL)
            statusText = L10n.format(
                "imageEditor.status.exported",
                standardizedURL.lastPathComponent
            )
            return true
        } catch {
            statusText = L10n.format(
                "imageEditor.status.exportFailedWithReason",
                error.localizedDescription
            )
            return false
        }
    }

    private var quickExportPNGSettings: ImageEditorExportSettings {
        var settings = ImageEditorExportSettings()
        settings.format = .png
        settings.scope = .composited
        settings.scale = 1
        settings.batchScales = []
        settings.namingRule = .sourceName
        return settings
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

    func sliceExportPlan(settings: ImageEditorExportSettings) -> [ImageEditorSliceExportVariant] {
        var variants: [ImageEditorSliceExportVariant] = []
        var usedFilenames: Set<String> = []

        for slice in availableSlices {
            let resolved = resolvedSliceExportSettings(for: slice, defaults: settings)

            for variantSettings in resolved.settings {
                let includesScaleSuffix = !resolved.usesPresets && resolved.settings.count > 1
                let proposedFilename = exportFilename(
                    settings: variantSettings,
                    scale: variantSettings.scale,
                    includesScaleSuffix: includesScaleSuffix
                )
                let filename = Self.uniqueExportFilename(
                    proposedFilename,
                    usedFilenames: &usedFilenames
                )
                variants.append(
                    ImageEditorSliceExportVariant(
                        sliceID: slice.id,
                        filename: filename,
                        settings: variantSettings
                    )
                )
            }
        }
        return variants
    }

    private func resolvedSliceExportSettings(
        for slice: ImageEditorSlice,
        defaults: ImageEditorExportSettings
    ) -> (settings: [ImageEditorExportSettings], usesPresets: Bool) {
        let presetSettings = (slice.exportPresets ?? []).compactMap { preset -> ImageEditorExportSettings? in
            guard preset.format.supportsSliceExportPreset,
                  let scale = preset.resolvedScale(for: slice.frame)
            else { return nil }
            var settings = defaults
            settings.format = preset.format
            settings.scope = .slice
            settings.sliceID = slice.id
            settings.scale = scale
            settings.batchScales = []
            settings.filenameSuffix = preset.suffix
            return normalizedExportSettings(settings)
        }
        guard presetSettings.isEmpty else { return (presetSettings, true) }

        var fallback = defaults
        if fallback.format == .svg || fallback.format == .psd {
            fallback.format = .png
        }
        fallback.scope = .slice
        fallback.sliceID = slice.id
        fallback.filenameSuffix = ""
        fallback = normalizedExportSettings(fallback)
        let settings = exportScales(for: fallback).map { scale in
            var variant = fallback
            variant.scale = scale
            variant.batchScales = []
            return variant
        }
        return (settings, false)
    }

    func sliceExportArtifacts(
        settings: ImageEditorExportSettings
    ) -> [ImageEditorSliceExportArtifact]? {
        sliceExportArtifacts(plan: sliceExportPlan(settings: settings))
    }

    private func sliceExportArtifacts(
        plan: [ImageEditorSliceExportVariant]
    ) -> [ImageEditorSliceExportArtifact]? {
        guard !plan.isEmpty else { return nil }
        var artifacts: [ImageEditorSliceExportArtifact] = []
        artifacts.reserveCapacity(plan.count)
        for variant in plan {
            guard let data = exportData(settings: variant.settings) else { return nil }
            artifacts.append(ImageEditorSliceExportArtifact(variant: variant, data: data))
        }
        return artifacts
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

    func runExportAllSlices() {
        let settings = normalizedExportSettings(exportSettings)
        let plan = sliceExportPlan(settings: settings)
        guard !plan.isEmpty else {
            statusText = L10n.text("imageEditor.status.exportFailed")
            return
        }
        guard !plan.contains(where: { $0.settings.format == .webp })
                || NSImage.canWriteImage(typeIdentifier: UTType.webP.identifier)
        else {
            statusText = L10n.text("imageEditor.status.exportWebPUnsupported")
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.text("imageEditor.export.chooseFolder")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let directory = panel.url else { return }
                self.exportAllSlices(settings: settings, to: directory)
            }
        }
    }

    func chooseLayerCompExportDirectory(
        scope: ImageEditorLayerCompExportScope = .all
    ) {
        guard !layerCompsForExport(scope: scope).isEmpty else { return }
        let formats = Self.layerCompExportFormats
        let selectedFormat = formats.contains(exportSettings.format) ? exportSettings.format : .png
        let formatPicker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 150, height: 26))
        for format in formats {
            formatPicker.addItem(withTitle: format.title)
        }
        formatPicker.selectItem(at: formats.firstIndex(of: selectedFormat) ?? 0)
        let formatLabel = NSTextField(labelWithString: L10n.text("imageEditor.export.layerCompsFormat"))
        let accessory = NSStackView(views: [formatLabel, formatPicker])
        accessory.orientation = .horizontal
        accessory.spacing = 8
        accessory.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        accessory.frame = NSRect(x: 0, y: 0, width: 310, height: 34)

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.text("imageEditor.export.chooseFolder")
        panel.accessoryView = accessory
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let directory = panel.url else { return }
                let index = formatPicker.indexOfSelectedItem
                guard formats.indices.contains(index) else { return }
                let format = formats[index]
                self.exportSettings.format = format
                _ = self.exportLayerComps(
                    format: format,
                    quality: self.exportSettings.quality,
                    to: directory,
                    scope: scope
                )
            }
        }
    }

    func chooseLayerCompPDFDestination(
        scope: ImageEditorLayerCompExportScope = .all
    ) {
        guard !layerCompsForExport(scope: scope).isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = layerCompPDFExportFilename(scope: scope)
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let destination = panel.url else { return }
                _ = self.exportLayerCompsPDF(to: destination, scope: scope)
            }
        }
    }

    var layerCompPDFExportFilename: String {
        layerCompPDFExportFilename(scope: .all)
    }

    func layerCompPDFExportFilename(scope: ImageEditorLayerCompExportScope) -> String {
        let rawSourceName = (document.sourceName as NSString).deletingPathExtension
        let sourceName = Self.sanitizedExportBasename(rawSourceName, fallback: "image")
        let suffix = scope == .favorites ? "favorite-layer-comps" : "layer-comps"
        return "\(sourceName)-\(suffix).pdf"
    }

    func layerCompExportPlan(
        format: ImageEditorExportFormat,
        scope: ImageEditorLayerCompExportScope = .all
    ) -> [ImageEditorLayerCompExportVariant] {
        guard Self.layerCompExportFormats.contains(format) else { return [] }
        let layerComps = layerCompsForExport(scope: scope)
        let rawSourceName = (document.sourceName as NSString).deletingPathExtension
        let sourceName = Self.sanitizedExportBasename(rawSourceName, fallback: "image")
        var usedFilenames: Set<String> = []
        return layerComps.enumerated().map { index, comp in
            let compName = Self.sanitizedExportBasename(
                comp.name,
                fallback: "layer-comp-\(index + 1)"
            )
            let filename = Self.uniqueExportFilename(
                "\(sourceName)-\(compName).\(format.filenameExtension)",
                usedFilenames: &usedFilenames
            )
            return ImageEditorLayerCompExportVariant(
                layerCompID: comp.id,
                filename: filename
            )
        }
    }

    func layerCompExportArtifacts(
        format: ImageEditorExportFormat,
        quality: Double = 0.9,
        scope: ImageEditorLayerCompExportScope = .all
    ) -> [ImageEditorLayerCompExportArtifact]? {
        let plan = layerCompExportPlan(format: format, scope: scope)
        guard !plan.isEmpty,
              let exportDocuments = layerCompExportDocuments(scope: scope),
              exportDocuments.count == plan.count
        else { return nil }
        var artifacts: [ImageEditorLayerCompExportArtifact] = []
        artifacts.reserveCapacity(plan.count)
        for (variant, exportDocument) in zip(plan, exportDocuments) {
            guard let data = layerCompExportData(
                document: exportDocument,
                format: format,
                quality: quality
            ) else { return nil }
            artifacts.append(ImageEditorLayerCompExportArtifact(variant: variant, data: data))
        }
        return artifacts
    }

    func layerCompExportDocuments(
        scope: ImageEditorLayerCompExportScope = .all
    ) -> [ImageEditorDocument]? {
        let layerComps = layerCompsForExport(scope: scope)
        guard !layerComps.isEmpty else { return nil }
        var exportDocuments: [ImageEditorDocument] = []
        exportDocuments.reserveCapacity(layerComps.count)
        for comp in layerComps {
            guard ImageEditorLayerCompApplication.hasMatchingLayers(comp, in: document) else {
                return nil
            }
            var exportDocument = document
            ImageEditorLayerCompApplication.apply(
                comp,
                to: &exportDocument,
                selectedLayerCompID: comp.id
            )
            exportDocuments.append(exportDocument)
        }
        return exportDocuments
    }

    func layerCompMultipagePDFData(
        scope: ImageEditorLayerCompExportScope = .all
    ) -> Data? {
        guard let exportDocuments = layerCompExportDocuments(scope: scope) else { return nil }
        return NSImage.pdfData(pages: exportDocuments.map(\.compositedImage))
    }

    @discardableResult
    func exportLayerCompsPDF(
        to destination: URL,
        scope: ImageEditorLayerCompExportScope = .all,
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
        dataWriter: (Data, URL) throws -> Void = { data, destination in
            try data.write(to: destination, options: .withoutOverwriting)
        }
    ) -> Bool {
        let layerCompCount = layerCompsForExport(scope: scope).count
        guard let data = layerCompMultipagePDFData(scope: scope) else {
            statusText = L10n.text("imageEditor.status.exportLayerCompsFailed")
            return false
        }
        let standardizedDestination = destination.standardizedFileURL
        guard !fileExists(standardizedDestination) else {
            statusText = L10n.format("imageEditor.status.exportLayerCompConflicts", 1)
            return false
        }
        do {
            try dataWriter(data, standardizedDestination)
            statusText = L10n.format(
                "imageEditor.status.exportedLayerComps",
                layerCompCount,
                standardizedDestination.lastPathComponent
            )
            return true
        } catch {
            statusText = L10n.format(
                "imageEditor.status.exportFailedWithReason",
                error.localizedDescription
            )
            return false
        }
    }

    @discardableResult
    func exportLayerComps(
        format: ImageEditorExportFormat,
        quality: Double = 0.9,
        to directory: URL,
        scope: ImageEditorLayerCompExportScope = .all,
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
        dataWriter: (Data, URL) throws -> Void = { data, destination in
            try data.write(to: destination, options: .withoutOverwriting)
        }
    ) -> Int {
        guard let artifacts = layerCompExportArtifacts(
            format: format,
            quality: quality,
            scope: scope
        ) else {
            statusText = L10n.text("imageEditor.status.exportLayerCompsFailed")
            return 0
        }
        let standardizedDirectory = directory.standardizedFileURL
        let destinations = artifacts.map { artifact in
            standardizedDirectory.appendingPathComponent(artifact.variant.filename, isDirectory: false)
        }
        let conflictCount = destinations.filter(fileExists).count
        guard conflictCount == 0 else {
            statusText = L10n.format("imageEditor.status.exportLayerCompConflicts", conflictCount)
            return 0
        }
        do {
            for (artifact, destination) in zip(artifacts, destinations) {
                try dataWriter(artifact.data, destination)
            }
            statusText = L10n.format(
                "imageEditor.status.exportedLayerComps",
                artifacts.count,
                standardizedDirectory.lastPathComponent
            )
            return artifacts.count
        } catch {
            statusText = L10n.format(
                "imageEditor.status.exportFailedWithReason",
                error.localizedDescription
            )
            return 0
        }
    }

    private func layerCompsForExport(
        scope: ImageEditorLayerCompExportScope
    ) -> [ImageEditorLayerComp] {
        switch scope {
        case .all:
            return document.layerComps
        case .favorites:
            return document.layerComps.filter(\.isFavorite)
        }
    }

    private func layerCompExportData(
        document: ImageEditorDocument,
        format: ImageEditorExportFormat,
        quality: Double
    ) -> Data? {
        let normalizedQuality = min(1, max(0.1, quality))
        switch format {
        case .png:
            return document.compositedImage.qingtuPNGData()
        case .jpeg:
            return document.compositedImage
                .flattened(on: .white)
                .bitmapData(type: .jpeg, quality: normalizedQuality)
        case .webp:
            guard NSImage.canWriteImage(typeIdentifier: UTType.webP.identifier) else { return nil }
            return document.compositedImage.bitmapData(
                typeIdentifier: UTType.webP.identifier,
                quality: normalizedQuality
            )
        case .pdf:
            return document.compositedImage.pdfData()
        case .psd:
            return try? ImageEditorPSDCodec.encode(document: document)
        case .svg:
            return nil
        }
    }

    @discardableResult
    func exportAllSlices(settings: ImageEditorExportSettings, to directory: URL) -> Int {
        let currentPlan = sliceExportPlan(settings: settings)
        guard !currentPlan.isEmpty else {
            statusText = L10n.text("imageEditor.status.exportFailed")
            return 0
        }
        let resolution = ImageEditorSliceExportConflictPolicy.resolve(
            plan: currentPlan,
            policy: settings.sliceConflictPolicy
        ) { filename in
            let url = directory.appendingPathComponent(filename, isDirectory: false)
            return FileManager.default.fileExists(atPath: url.path)
        }
        if settings.sliceConflictPolicy == .abort,
           !resolution.conflictingFilenames.isEmpty {
            statusText = L10n.format(
                "imageEditor.status.exportSliceConflicts",
                resolution.conflictingFilenames.count
            )
            return 0
        }
        guard !resolution.deliverablePlan.isEmpty else {
            statusText = L10n.format(
                "imageEditor.status.exportSlicesAllSkipped",
                resolution.conflictingFilenames.count
            )
            return 0
        }
        guard let artifacts = sliceExportArtifacts(plan: resolution.deliverablePlan) else {
            statusText = L10n.text("imageEditor.status.exportFailed")
            return 0
        }
        do {
            for artifact in artifacts {
                let destination = directory.appendingPathComponent(
                    artifact.variant.filename,
                    isDirectory: false
                )
                try artifact.data.write(to: destination, options: .withoutOverwriting)
            }
            statusText = resolution.conflictingFilenames.isEmpty
                ? L10n.format(
                    "imageEditor.status.exportedAllSlices",
                    artifacts.count,
                    directory.lastPathComponent
                )
                : L10n.format(
                    "imageEditor.status.exportedSlicesSkippingExisting",
                    artifacts.count,
                    resolution.conflictingFilenames.count,
                    directory.lastPathComponent
                )
            isExportSheetPresented = false
            return artifacts.count
        } catch {
            statusText = L10n.format(
                "imageEditor.status.exportFailedWithReason",
                error.localizedDescription
            )
            return 0
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
        let supportedScaleRange = ImageEditorExportSettings.supportedScaleRange
        normalized.scale = min(
            supportedScaleRange.upperBound,
            max(supportedScaleRange.lowerBound, normalized.scale)
        )
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
        guard let selectedBounds = selection.effectiveSelectedBounds(in: document.canvasSize) else { return nil }
        let bounded = selectedBounds.standardized
            .intersection(canvasBounds)
            .integral
            .intersection(canvasBounds)
        guard bounded.width > 0, bounded.height > 0 else { return nil }
        return bounded
    }

    func selectedSelectionExportImage() -> NSImage? {
        guard let selection = document.selection,
              let bounds = selectionExportBounds,
              let composited = document.compositedImage.croppedFromTopLeftCanvas(to: bounds),
              let mask = selectionExportMask(for: selection)?.croppedFromTopLeftCanvas(to: bounds)
        else { return nil }

        return composited.applyingExportAlphaMask(mask)
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

    func selectedLayerExportImage() -> NSImage? {
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
        if settings.scope == .slice,
           let sliceID = settings.sliceID,
           let slice = slice(with: sliceID) {
            let sliceName = Self.sanitizedExportBasename(slice.name, fallback: "slice")
            let presetSuffix = ImageEditorSliceExportPreset.sanitizedSuffix(settings.filenameSuffix)
            let scaleSuffix = includesScaleSuffix && settings.usesScale
                ? "@\(exportScaleLabel(scale))"
                : ""
            return "\(sliceName)\(presetSuffix)\(scaleSuffix).\(settings.format.filenameExtension)"
        }
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

    private static func sanitizedExportBasename(_ rawValue: String, fallback: String) -> String {
        let sanitized = ImageEditorSliceExportPreset.sanitizedFilenameComponent(rawValue)
        return sanitized.isEmpty ? fallback : sanitized
    }

    private static func uniqueExportFilename(
        _ filename: String,
        usedFilenames: inout Set<String>
    ) -> String {
        let key = filename.lowercased()
        guard usedFilenames.contains(key) else {
            usedFilenames.insert(key)
            return filename
        }
        let pathExtension = (filename as NSString).pathExtension
        let basename = (filename as NSString).deletingPathExtension
        var occurrence = 2
        while true {
            let candidate: String
            if pathExtension.isEmpty {
                candidate = "\(basename)-\(occurrence)"
            } else {
                candidate = "\(basename)-\(occurrence).\(pathExtension)"
            }
            if !usedFilenames.contains(candidate.lowercased()) {
                usedFilenames.insert(candidate.lowercased())
                return candidate
            }
            occurrence += 1
        }
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

    private var svgExportPlan: ImageEditorSVGExportPlan? {
        svgExportPlan(includingOnly: nil)
    }

    private var selectedLayersSVGExportPlan: ImageEditorSVGExportPlan? {
        guard !document.selectedLayerIDs.isEmpty else { return nil }
        return svgExportPlan(includingOnly: document.selectedLayerIDs)
    }

    private func svgExportPlan(
        includingOnly includedLayerIDs: Set<UUID>?
    ) -> ImageEditorSVGExportPlan? {
        let visibleLayers = document.layers.filter { layer in
            document.shouldComposite(layer)
                && includedLayerIDs.map { isLayer(layer, includedIn: $0) } != false
        }
        for layer in visibleLayers {
            guard canSerializeAsSVG(layer) else { return nil }
        }
        let exportLayers = visibleLayers.filter { layer in
            switch layer.kind {
            case .text, .shape:
                true
            default:
                false
            }
        }
        var groupIDs = Set<UUID>()
        for layer in exportLayers {
            let ancestors = document.ancestorGroups(for: layer)
            if let groupID = layer.groupID {
                guard ancestors.first?.id == groupID,
                      ancestors.last?.groupID == nil
                else { return nil }
            }
            for group in ancestors {
                guard canSerializeAsSVGGroup(group) else { return nil }
                groupIDs.insert(group.id)
            }
        }
        guard includedLayerIDs == nil || !exportLayers.isEmpty else { return nil }
        return (exportLayers, groupIDs)
    }

    private func canSerializeAsSVGGroup(_ layer: ImageEditorLayer) -> Bool {
        guard layer.isGroup,
              layer.blendMode == .passThrough || layer.blendMode == .normal,
              layer.opacity.isFinite,
              (0...1).contains(layer.opacity),
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
        return true
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
        case .text:
            return true
        case let .shape(content):
            if content.fillOpacity > 0,
               let gradient = content.fillGradient,
               content.kind != .path || content.isPathClosed {
                let normalized = gradient.normalized()
                guard !normalized.dither,
                      normalized.style != .diamond,
                      normalized.style != .angle else {
                    return false
                }
            }
            return true
        case .pixel:
            return layer.image.nonTransparentPixelBounds() == nil
        default:
            return false
        }
    }

    private func svgData() -> Data? {
        guard let plan = svgExportPlan else { return nil }
        let size = document.canvasSize
        return svgData(
            plan: plan,
            viewport: CGRect(origin: .zero, size: size)
        )
    }

    private func svgData(
        plan: ImageEditorSVGExportPlan,
        viewport: CGRect
    ) -> Data? {
        let bounds = viewport.standardized
        guard bounds.width > 0,
              bounds.height > 0,
              bounds.minX.isFinite,
              bounds.minY.isFinite,
              bounds.width.isFinite,
              bounds.height.isFinite
        else { return nil }
        let elements = svgHierarchyElements(
            exportLayerIDs: Set(plan.layers.map(\.id)),
            exportGroupIDs: plan.groupIDs,
            parentGroupID: nil,
            visitedGroupIDs: []
        )
        let source = [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(svgNumber(bounds.width))\" height=\"\(svgNumber(bounds.height))\" viewBox=\"\(svgNumber(bounds.minX)) \(svgNumber(bounds.minY)) \(svgNumber(bounds.width)) \(svgNumber(bounds.height))\">",
            elements.joined(separator: "\n"),
            "</svg>"
        ].joined(separator: "\n")
        return source.data(using: .utf8)
    }

    private func svgHierarchyElements(
        exportLayerIDs: Set<UUID>,
        exportGroupIDs: Set<UUID>,
        parentGroupID: UUID?,
        visitedGroupIDs: Set<UUID>
    ) -> [String] {
        document.layers.compactMap { layer in
            guard layer.groupID == parentGroupID else { return nil }
            if exportLayerIDs.contains(layer.id) {
                var effectiveLayer = layer
                effectiveLayer.opacity *= svgPassThroughAncestorOpacity(for: layer)
                let element: String
                switch effectiveLayer.kind {
                case let .shape(content):
                    element = svgShape(content, layer: effectiveLayer)
                case let .text(content):
                    element = svgText(content, layer: effectiveLayer)
                default:
                    return nil
                }
                return svgLayerGroup(element, layer: layer)
            }
            guard exportGroupIDs.contains(layer.id),
                  layer.isGroup,
                  !visitedGroupIDs.contains(layer.id)
            else { return nil }
            let content = svgHierarchyElements(
                exportLayerIDs: exportLayerIDs,
                exportGroupIDs: exportGroupIDs,
                parentGroupID: layer.id,
                visitedGroupIDs: visitedGroupIDs.union([layer.id])
            ).joined(separator: "\n")
            return svgLayerGroup(content, layer: layer)
        }
    }

    private func svgPassThroughAncestorOpacity(for layer: ImageEditorLayer) -> Double {
        document.ancestorGroups(for: layer)
            .prefix { $0.blendMode == .passThrough }
            .reduce(1) { $0 * $1.opacity }
    }

    private func svgLayerGroup(_ content: String, layer: ImageEditorLayer) -> String {
        let identifier = layer.id.uuidString
        let name = svgAttributeEscaped(layer.name)
        let title = svgEscaped(layer.name)
        let kind: String
        switch layer.kind {
        case .group: kind = "group"
        case .shape: kind = "shape"
        case .text: kind = "text"
        default: kind = "layer"
        }
        var metadata = "data-xomo-layer-kind=\"\(kind)\""
        if layer.isGroup {
            metadata += " data-xomo-blend-mode=\"\(layer.blendMode.rawValue)\" data-xomo-opacity=\"\(svgNumber(CGFloat(layer.opacity)))\""
            if layer.blendMode == .normal {
                let opacity = layer.opacity * svgPassThroughAncestorOpacity(for: layer)
                metadata += " opacity=\"\(svgNumber(CGFloat(opacity)))\" style=\"isolation:isolate\""
            }
        }
        return "<g id=\"xomo-layer-\(identifier)\" data-xomo-layer-id=\"\(identifier)\" data-name=\"\(name)\" \(metadata)>\n<title>\(title)</title>\n\(content)\n</g>"
    }

    private func svgShape(_ content: ImageEditorShapeContent, layer: ImageEditorLayer) -> String {
        let normalized = content.normalized(size: layer.image.size)
        let gradient = svgFillGradient(content: normalized, layer: layer)
        var attributes = svgPaintAttributes(
            content: normalized,
            layer: layer,
            fillReference: gradient?.reference
        )
        let markers = svgStrokeMarkers(content: normalized, layer: layer)
        if !markers.attributes.isEmpty {
            attributes += " \(markers.attributes)"
        }
        let element: String
        switch normalized.kind {
        case .rectangle:
            let inset = normalized.strokeWidth / 2
            if normalized.effectiveCornerRadii.hasRoundedCorner {
                let localSize = CGSize(
                    width: max(layer.image.size.width, 1),
                    height: max(layer.image.size.height, 1)
                )
                let localRect = CGRect(origin: .zero, size: localSize).insetBy(
                    dx: inset,
                    dy: inset
                )
                let radii = normalized.effectiveCornerRadii.normalized(size: localRect.size)
                let radiiValue = [
                    radii.topLeft,
                    radii.topRight,
                    radii.bottomRight,
                    radii.bottomLeft
                ].map(svgNumber).joined(separator: " ")
                let path = normalized.rectangleBezierPath(in: localRect)
                element = "<path d=\"\(svgBezierPathData(path, layer: layer))\" data-xomo-corner-radii=\"\(radiiValue)\" data-xomo-corner-smoothing=\"\(svgNumber(normalized.cornerSmoothing))\" \(attributes) />"
            } else {
                let frame = layer.frame.insetBy(dx: inset, dy: inset)
                element = "<rect x=\"\(svgNumber(frame.minX))\" y=\"\(svgNumber(frame.minY))\" width=\"\(svgNumber(frame.width))\" height=\"\(svgNumber(frame.height))\" \(attributes) />"
            }
        case .ellipse:
            element = "<ellipse cx=\"\(svgNumber(layer.frame.midX))\" cy=\"\(svgNumber(layer.frame.midY))\" rx=\"\(svgNumber(max(0, layer.frame.width - normalized.strokeWidth) / 2))\" ry=\"\(svgNumber(max(0, layer.frame.height - normalized.strokeWidth) / 2))\" \(attributes) />"
        case .path:
            element = "<path d=\"\(svgPathData(content: normalized, layer: layer))\" \(attributes) />"
        }
        let definitions = [gradient?.definition, markers.definitions.isEmpty ? nil : markers.definitions]
            .compactMap { $0 }
            .joined(separator: "\n")
        return definitions.isEmpty
            ? element
            : "<defs>\n\(definitions)\n</defs>\n\(element)"
    }

    private func svgText(_ content: ImageEditorTextContent, layer: ImageEditorLayer) -> String {
        let color = svgColor(content.color)
        let localSize = CGSize(
            width: max(layer.image.size.width, 1),
            height: max(layer.image.size.height, 1)
        )
        let drawingRect = content.drawingRect(in: localSize)
        let fontStyle = content.isItalic ? "italic" : "normal"
        let fontWeight = content.isBold ? "bold" : "normal"
        let textDecoration = svgTextDecoration(content)
        let anchor: String
        switch content.alignment {
        case .left:
            anchor = "start"
        case .center:
            anchor = "middle"
        case .right:
            anchor = "end"
        case .justified:
            anchor = "start"
        }
        let y = drawingRect.minY + content.fontSize
        let lineHeight = content.fontSize
            + max(0, content.lineSpacing)
            + max(0, content.paragraphSpacing)
        let lines = (content.textCase == .smallCaps ? content.text : content.displayText)
            .components(separatedBy: .newlines)
        let tspans = lines.enumerated().map { index, line in
            let verticalOffset = index == 0 ? "0" : svgNumber(lineHeight)
            let x = svgTextLineX(content: content, drawingRect: drawingRect, lineIndex: index)
            let value = content.textCase == .smallCaps
                ? svgSmallCapsLine(line, fontSize: content.fontSize)
                : svgEscaped(line)
            return "<tspan x=\"\(svgNumber(x))\" dy=\"\(verticalOffset)\">\(value)</tspan>"
        }.joined()
        return "<text y=\"\(svgNumber(y))\" text-anchor=\"\(anchor)\" font-family=\"\(svgAttributeEscaped(content.fontFamilyName))\" font-size=\"\(svgNumber(content.fontSize))\" font-weight=\"\(fontWeight)\" font-style=\"\(fontStyle)\" letter-spacing=\"\(svgNumber(content.characterSpacing))\" text-decoration=\"\(textDecoration)\" fill=\"\(color.hex)\" fill-opacity=\"\(svgNumber(color.alpha * layer.opacity))\" transform=\"\(svgLayerTransform(layer: layer, localSize: localSize))\" data-xomo-text-case=\"\(content.textCase.rawValue)\" data-xomo-vertical-alignment=\"\(content.verticalAlignment.rawValue)\">\(tspans)</text>"
    }

    private func svgTextLineX(
        content: ImageEditorTextContent,
        drawingRect: CGRect,
        lineIndex: Int
    ) -> CGFloat {
        let leftIndent = lineIndex == 0
            ? max(0, content.leftIndent + content.firstLineIndent)
            : max(0, content.leftIndent)
        let left = drawingRect.minX + leftIndent
        let right = drawingRect.maxX - max(0, content.rightIndent)
        switch content.alignment {
        case .left, .justified:
            return left
        case .center:
            return (left + right) / 2
        case .right:
            return right
        }
    }

    private func svgTextDecoration(_ content: ImageEditorTextContent) -> String {
        var values: [String] = []
        if content.isUnderlined { values.append("underline") }
        if content.isStruckThrough { values.append("line-through") }
        return values.isEmpty ? "none" : values.joined(separator: " ")
    }

    private func svgSmallCapsLine(_ line: String, fontSize: CGFloat) -> String {
        var result = ""
        var currentText = ""
        var currentIsSmall: Bool?
        func appendRun() {
            guard !currentText.isEmpty, let currentIsSmall else { return }
            let escaped = svgEscaped(currentText)
            if currentIsSmall {
                result += "<tspan font-size=\"\(svgNumber(max(6, fontSize * ImageEditorTextContent.smallCapsScale)))\">\(escaped)</tspan>"
            } else {
                result += escaped
            }
        }
        for character in line {
            let source = String(character)
            let displayed = source.uppercased()
            let isSmall = source != displayed && source == source.lowercased()
            if currentIsSmall != isSmall {
                appendRun()
                currentText = ""
                currentIsSmall = isSmall
            }
            currentText += displayed
        }
        appendRun()
        return result
    }

    private func svgLayerTransform(layer: ImageEditorLayer, localSize: CGSize) -> String {
        let scaleX = layer.frame.width / localSize.width
        let scaleY = layer.frame.height / localSize.height
        return "matrix(\(svgNumber(scaleX)) 0 0 \(svgNumber(scaleY)) \(svgNumber(layer.frame.minX)) \(svgNumber(layer.frame.minY)))"
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

    private func svgBezierPathData(_ path: NSBezierPath, layer: ImageEditorLayer) -> String {
        var commands: [String] = []
        var points = [NSPoint](repeating: .zero, count: 3)
        for index in 0..<path.elementCount {
            switch path.element(at: index, associatedPoints: &points) {
            case .moveTo:
                if index == path.elementCount - 1, commands.last == "Z" {
                    continue
                }
                commands.append("M \(svgPoint(points[0], layer: layer))")
            case .lineTo:
                commands.append("L \(svgPoint(points[0], layer: layer))")
            case .curveTo, .cubicCurveTo:
                commands.append("C \(svgPoint(points[0], layer: layer)) \(svgPoint(points[1], layer: layer)) \(svgPoint(points[2], layer: layer))")
            case .quadraticCurveTo:
                commands.append("Q \(svgPoint(points[0], layer: layer)) \(svgPoint(points[1], layer: layer))")
            case .closePath:
                commands.append("Z")
            @unknown default:
                continue
            }
        }
        return commands.joined(separator: " ")
    }

    private func svgPaintAttributes(
        content: ImageEditorShapeContent,
        layer: ImageEditorLayer,
        fillReference: String? = nil
    ) -> String {
        let fill = svgColor(content.fillColor)
        let stroke = svgColor(content.strokeColor)
        let supportsFill = content.kind != .path || content.isPathClosed
        let fillValue = supportsFill ? fillReference ?? fill.hex : "none"
        let fillAlpha = fillReference == nil ? fill.alpha : 1
        var attributes = [
            "fill=\"\(fillValue)\"",
            "fill-opacity=\"\(svgNumber(fillAlpha * content.fillOpacity * layer.opacity))\"",
            "stroke=\"\(stroke.hex)\"",
            "stroke-opacity=\"\(svgNumber(stroke.alpha * content.strokeOpacity * layer.opacity))\"",
            "stroke-width=\"\(svgNumber(content.strokeWidth))\"",
            "stroke-linejoin=\"\(content.strokeJoin.rawValue)\"",
            "stroke-linecap=\"\(content.strokeCap.rawValue)\"",
            "stroke-miterlimit=\"\(svgNumber(content.strokeMiterLimit))\""
        ]
        if !content.strokeDashPattern.isEmpty {
            attributes.append(
                "stroke-dasharray=\"\(content.strokeDashPattern.map { svgNumber($0) }.joined(separator: " "))\""
            )
            attributes.append("stroke-dashoffset=\"\(svgNumber(content.strokeDashOffset))\"")
        }
        if content.kind == .path {
            attributes.append("fill-rule=\"evenodd\"")
        }
        return attributes.joined(separator: " ")
    }

    private func svgFillGradient(
        content: ImageEditorShapeContent,
        layer: ImageEditorLayer
    ) -> (definition: String, reference: String)? {
        guard content.kind != .path || content.isPathClosed,
              let gradient = content.fillGradient?.normalized(),
              !gradient.dither,
              gradient.style != .diamond,
              gradient.style != .angle else {
            return nil
        }
        let identifier = layer.id.uuidString.replacingOccurrences(of: "-", with: "")
        let gradientID = "xomo-fill-gradient-\(identifier)"
        let localSize = CGSize(
            width: max(layer.image.size.width, 1),
            height: max(layer.image.size.height, 1)
        )
        let center = CGPoint(
            x: localSize.width * content.fillGradientCenter.x - 0.5,
            y: localSize.height * content.fillGradientCenter.y - 0.5
        )
        let transform = svgLayerTransform(layer: layer, localSize: localSize)
        let ramp = svgGradientRamp(gradient)
        let definition: String
        switch gradient.style {
        case .linear, .reflected:
            let radians = gradient.angle * .pi / 180
            let direction = CGVector(dx: cos(radians), dy: sin(radians))
            let span = max(
                1,
                abs(direction.dx) * localSize.width + abs(direction.dy) * localSize.height
            ) * gradient.scale
            let halfSpan = span / 2
            let start = CGPoint(
                x: center.x - direction.dx * halfSpan,
                y: center.y - direction.dy * halfSpan
            )
            let end = CGPoint(
                x: center.x + direction.dx * halfSpan,
                y: center.y + direction.dy * halfSpan
            )
            let stops = gradient.style == .reflected
                ? svgReflectedGradientStops(ramp)
                : svgGradientStops(ramp)
            definition = "<linearGradient id=\"\(gradientID)\" gradientUnits=\"userSpaceOnUse\" x1=\"\(svgNumber(start.x))\" y1=\"\(svgNumber(start.y))\" x2=\"\(svgNumber(end.x))\" y2=\"\(svgNumber(end.y))\" gradientTransform=\"\(transform)\" spreadMethod=\"pad\" data-xomo-gradient-style=\"\(gradient.style.rawValue)\">\(stops)</linearGradient>"
        case .radial:
            let radius = max(
                1,
                hypot(localSize.width - 1, localSize.height - 1) / 2 * gradient.scale
            )
            definition = "<radialGradient id=\"\(gradientID)\" gradientUnits=\"userSpaceOnUse\" cx=\"\(svgNumber(center.x))\" cy=\"\(svgNumber(center.y))\" r=\"\(svgNumber(radius))\" fx=\"\(svgNumber(center.x))\" fy=\"\(svgNumber(center.y))\" gradientTransform=\"\(transform)\" spreadMethod=\"pad\" data-xomo-gradient-style=\"radial\">\(svgGradientStops(ramp))</radialGradient>"
        case .diamond:
            return nil
        case .angle:
            return nil
        }
        return (definition, "url(#\(gradientID))")
    }

    private func svgGradientRamp(
        _ gradient: ImageEditorGradientFillContent
    ) -> [(position: Double, color: NSColor)] {
        var stops = gradient.shapeColorStops
        if gradient.reverse {
            let forward = stops
            stops = forward.indices.reversed().map { index in
                let stop = forward[index]
                return ImageEditorGradientColorStop(
                    position: 1 - stop.position,
                    red: stop.red,
                    green: stop.green,
                    blue: stop.blue,
                    alpha: stop.alpha,
                    midpoint: index > forward.startIndex
                        ? 1 - forward[index - 1].midpoint
                        : ImageEditorGradientColorStop.defaultMidpoint
                )
            }
        }
        guard let first = stops.first else { return [] }
        var ramp: [(position: Double, color: NSColor)] = [(first.position, first.color)]
        for index in stops.indices.dropFirst() {
            let lower = stops[index - 1]
            let upper = stops[index]
            let distance = upper.position - lower.position
            if distance > 0.000_001,
               abs(lower.midpoint - ImageEditorGradientColorStop.defaultMidpoint) > 0.000_001 {
                ramp.append((
                    lower.position + distance * lower.midpoint,
                    NSColor(
                        deviceRed: (lower.red + upper.red) / 2,
                        green: (lower.green + upper.green) / 2,
                        blue: (lower.blue + upper.blue) / 2,
                        alpha: (lower.alpha + upper.alpha) / 2
                    )
                ))
            }
            ramp.append((upper.position, upper.color))
        }
        return ramp
    }

    private func svgGradientStops(
        _ ramp: [(position: Double, color: NSColor)]
    ) -> String {
        ramp.map { stop in
            svgGradientStop(position: stop.position, color: stop.color)
        }.joined()
    }

    private func svgReflectedGradientStops(
        _ ramp: [(position: Double, color: NSColor)]
    ) -> String {
        let left = ramp.reversed().map { stop in
            svgGradientStop(position: (1 - stop.position) / 2, color: stop.color)
        }
        let right = ramp.dropFirst().map { stop in
            svgGradientStop(position: 0.5 + stop.position / 2, color: stop.color)
        }
        return (left + right).joined()
    }

    private func svgGradientStop(position: Double, color: NSColor) -> String {
        let value = svgColor(color)
        return "<stop offset=\"\(svgNumber(CGFloat(position)))\" stop-color=\"\(value.hex)\" stop-opacity=\"\(svgNumber(value.alpha))\" />"
    }

    private func svgStrokeMarkers(
        content: ImageEditorShapeContent,
        layer: ImageEditorLayer
    ) -> (definitions: String, attributes: String) {
        guard content.kind == .path, !content.isPathClosed else { return ("", "") }
        let identifier = layer.id.uuidString.replacingOccurrences(of: "-", with: "")
        var definitions: [String] = []
        var attributes: [String] = []
        if content.strokeStartDecoration != .none {
            let markerID = "xomo-marker-start-\(identifier)"
            definitions.append(
                svgStrokeMarkerDefinition(
                    id: markerID,
                    decoration: content.strokeStartDecoration,
                    content: content,
                    layer: layer,
                    isStart: true
                )
            )
            attributes.append("marker-start=\"url(#\(markerID))\"")
        }
        if content.strokeEndDecoration != .none {
            let markerID = "xomo-marker-end-\(identifier)"
            definitions.append(
                svgStrokeMarkerDefinition(
                    id: markerID,
                    decoration: content.strokeEndDecoration,
                    content: content,
                    layer: layer,
                    isStart: false
                )
            )
            attributes.append("marker-end=\"url(#\(markerID))\"")
        }
        return (definitions.joined(separator: "\n"), attributes.joined(separator: " "))
    }

    private func svgStrokeMarkerDefinition(
        id: String,
        decoration: ImageEditorStrokeDecoration,
        content: ImageEditorShapeContent,
        layer: ImageEditorLayer,
        isStart: Bool
    ) -> String {
        let halfWidth = max(2.5, content.strokeWidth / 2 + 2.5)
        let length = max(6, content.strokeWidth * 4)
        let stroke = svgColor(content.strokeColor)
        let opacity = svgNumber(stroke.alpha * content.strokeOpacity * layer.opacity)
        let fillAttributes = "fill=\"\(stroke.hex)\" fill-opacity=\"\(opacity)\""
        let body: String
        switch decoration {
        case .none:
            body = ""
        case .openArrow:
            body = "<path d=\"M -\(svgNumber(length)) \(svgNumber(halfWidth)) L 0 0 L -\(svgNumber(length)) -\(svgNumber(halfWidth))\" fill=\"none\" stroke=\"\(stroke.hex)\" stroke-opacity=\"\(opacity)\" stroke-width=\"\(svgNumber(max(1, content.strokeWidth)))\" stroke-linecap=\"round\" stroke-linejoin=\"round\" />"
        case .filledArrow:
            body = "<path d=\"M 0 0 L -\(svgNumber(length)) \(svgNumber(halfWidth)) L -\(svgNumber(length * 0.72)) 0 L -\(svgNumber(length)) -\(svgNumber(halfWidth)) Z\" \(fillAttributes) stroke=\"none\" data-xomo-decoration=\"\(decoration.rawValue)\" />"
        case .filledTriangle:
            body = "<path d=\"M 0 \(svgNumber(halfWidth)) L 0 -\(svgNumber(halfWidth)) L -\(svgNumber(length)) 0 Z\" \(fillAttributes) stroke=\"none\" data-xomo-decoration=\"\(decoration.rawValue)\" />"
        case .filledDiamond:
            body = "<path d=\"M 0 0 L -\(svgNumber(length * 0.5)) \(svgNumber(halfWidth)) L -\(svgNumber(length)) 0 L -\(svgNumber(length * 0.5)) -\(svgNumber(halfWidth)) Z\" \(fillAttributes) stroke=\"none\" data-xomo-decoration=\"\(decoration.rawValue)\" />"
        case .filledCircle:
            body = "<circle cx=\"-\(svgNumber(halfWidth))\" cy=\"0\" r=\"\(svgNumber(halfWidth))\" \(fillAttributes) stroke=\"none\" data-xomo-decoration=\"\(decoration.rawValue)\" />"
        }
        let orientation = isStart ? "auto-start-reverse" : "auto"
        return "<marker id=\"\(id)\" markerUnits=\"userSpaceOnUse\" markerWidth=\"\(svgNumber(length * 2))\" markerHeight=\"\(svgNumber(halfWidth * 2))\" refX=\"0\" refY=\"0\" orient=\"\(orientation)\" overflow=\"visible\" data-xomo-decoration=\"\(decoration.rawValue)\">\(body)</marker>"
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

    private func svgAttributeEscaped(_ value: String) -> String {
        svgEscaped(value)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
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

    /// ImageEditor canvas geometry uses a top-left origin while AppKit image
    /// drawing uses a bottom-left origin. Keep that conversion explicit at the
    /// export boundary so the selected pixels and their mask stay aligned.
    func croppedFromTopLeftCanvas(to rect: CGRect) -> NSImage? {
        let bounded = rect.standardized.intersection(CGRect(origin: .zero, size: size))
        guard bounded.width > 0, bounded.height > 0 else { return nil }
        let sourceRect = CGRect(
            x: bounded.minX,
            y: size.height - bounded.maxY,
            width: bounded.width,
            height: bounded.height
        )
        return NSImage.rendered(size: bounded.size) { outputRect in
            draw(
                in: outputRect,
                from: sourceRect,
                operation: .copy,
                fraction: 1
            )
        }
    }

    /// Applies the mask deterministically instead of relying on AppKit blend
    /// operations whose alpha result can vary with the backing image format.
    func applyingExportAlphaMask(_ mask: NSImage) -> NSImage? {
        guard size.width > 0, size.height > 0, mask.size == size else { return nil }
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        guard var sourcePixels = rgbaPixelsForExport(width: width, height: height),
              let maskPixels = mask.rgbaPixelsForExport(width: width, height: height)
        else { return nil }

        for offset in stride(from: 0, to: sourcePixels.count, by: bytesPerPixel) {
            let maskAlpha = Int(maskPixels[offset + 3])
            sourcePixels[offset] = UInt8(Int(sourcePixels[offset]) * maskAlpha / 255)
            sourcePixels[offset + 1] = UInt8(Int(sourcePixels[offset + 1]) * maskAlpha / 255)
            sourcePixels[offset + 2] = UInt8(Int(sourcePixels[offset + 2]) * maskAlpha / 255)
            sourcePixels[offset + 3] = UInt8(Int(sourcePixels[offset + 3]) * maskAlpha / 255)
        }

        guard let provider = CGDataProvider(data: Data(sourcePixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else { return nil }
        return NSImage(cgImage: cgImage, size: size)
    }

    func rgbaPixelsForExport(width: Int, height: Int) -> [UInt8]? {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
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
        Self.pdfData(pages: [self])
    }

    static func pdfData(pages: [NSImage]) -> Data? {
        guard let firstPage = pages.first,
              firstPage.size.width > 0,
              firstPage.size.height > 0,
              pages.allSatisfy({ $0.size == firstPage.size })
        else { return nil }
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output) else { return nil }
        var mediaBox = CGRect(origin: .zero, size: firstPage.size)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
        for page in pages {
            context.beginPDFPage(nil)
            context.saveGState()
            context.translateBy(x: 0, y: page.size.height)
            context.scaleBy(x: 1, y: -1)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            page.draw(
                in: CGRect(origin: .zero, size: page.size),
                from: CGRect(origin: .zero, size: page.size),
                operation: .sourceOver,
                fraction: 1
            )
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
            context.endPDFPage()
        }
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
