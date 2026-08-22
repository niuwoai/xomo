//
//  ImageEditorBrushPresetManager.swift
//  veilpic
//
//  Created by Codex on 2026/8/22.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

enum ImageEditorBrushPresetLibraryError: Error, Equatable {
    case fileTooLarge
    case invalidFile
    case unsupportedFormatVersion
    case emptyLibrary
    case noMatchingPresets
}

struct ImageEditorBrushPresetLibrary: Codable, Equatable {
    static let currentFormatVersion = 1
    static let maximumFileSize = 5 * 1_024 * 1_024
    static let fileExtension = "xomobrushes"

    let formatVersion: Int
    let presets: [ImageEditorBrushPreset]

    init(
        formatVersion: Int = currentFormatVersion,
        presets: [ImageEditorBrushPreset]
    ) {
        self.formatVersion = formatVersion
        self.presets = presets
    }
}

struct ImageEditorBrushPresetImportResult: Equatable {
    let importedCount: Int
    let skippedCount: Int
}

enum ImageEditorBrushPresetDropPolicy {
    static func acceptedURL(from urls: [URL]) -> URL? {
        guard urls.count == 1,
              let url = urls.first,
              url.isFileURL,
              url.pathExtension.caseInsensitiveCompare(
                ImageEditorBrushPresetLibrary.fileExtension
              ) == .orderedSame
        else { return nil }
        return url
    }
}

@MainActor
extension ImageEditorViewModel {
    static var brushPresetContentType: UTType {
        UTType(exportedAs: "im.some.xomo.brush-presets", conformingTo: .json)
    }

    func brushPresetLibraryData(presetIDs: [String]? = nil) throws -> Data {
        let presets: [ImageEditorBrushPreset]
        if let presetIDs {
            let indexedPresets = Dictionary(
                uniqueKeysWithValues: customBrushPresets.map { ($0.id, $0) }
            )
            presets = presetIDs.compactMap { indexedPresets[$0] }
        } else {
            presets = customBrushPresets
        }
        guard !presets.isEmpty else {
            throw ImageEditorBrushPresetLibraryError.noMatchingPresets
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(ImageEditorBrushPresetLibrary(presets: presets))
    }

    @discardableResult
    func importBrushPresetLibraryData(_ data: Data) throws -> ImageEditorBrushPresetImportResult {
        let library = try decodedBrushPresetLibrary(from: data)
        let availableCount = max(
            0,
            ImageEditorBrushPresetPreferences.maximumPresetCount - customBrushPresets.count
        )
        let importedPresets = preparedBrushPresets(
            from: library.presets,
            limit: availableCount,
            existingNames: Set(customBrushPresets.compactMap(\.name))
        )

        installImportedBrushPresets(importedPresets)
        let result = ImageEditorBrushPresetImportResult(
            importedCount: importedPresets.count,
            skippedCount: library.presets.count - importedPresets.count
        )
        statusText = L10n.format(
            "imageEditor.status.brushPresetImported",
            result.importedCount,
            result.skippedCount
        )
        return result
    }

    @discardableResult
    func replaceBrushPresetLibraryData(
        _ data: Data
    ) throws -> ImageEditorBrushPresetImportResult {
        let library = try decodedBrushPresetLibrary(from: data)
        let replacementPresets = preparedBrushPresets(
            from: library.presets,
            limit: ImageEditorBrushPresetPreferences.maximumPresetCount,
            existingNames: []
        )

        installReplacingBrushPresets(replacementPresets)
        let result = ImageEditorBrushPresetImportResult(
            importedCount: replacementPresets.count,
            skippedCount: library.presets.count - replacementPresets.count
        )
        statusText = L10n.format(
            "imageEditor.status.brushPresetLibraryReplaced",
            result.importedCount,
            result.skippedCount
        )
        return result
    }

    func exportBrushPresetLibrary(to url: URL, presetIDs: [String]? = nil) throws {
        try brushPresetLibraryData(presetIDs: presetIDs).write(to: url, options: .atomic)
        statusText = L10n.format("imageEditor.status.brushPresetExported", url.lastPathComponent)
    }

    @discardableResult
    func importBrushPresetLibrary(from url: URL) throws -> ImageEditorBrushPresetImportResult {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize,
           fileSize > ImageEditorBrushPresetLibrary.maximumFileSize {
            throw ImageEditorBrushPresetLibraryError.fileTooLarge
        }
        return try importBrushPresetLibraryData(Data(contentsOf: url))
    }

    @discardableResult
    func replaceBrushPresetLibrary(
        from url: URL
    ) throws -> ImageEditorBrushPresetImportResult {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize,
           fileSize > ImageEditorBrushPresetLibrary.maximumFileSize {
            throw ImageEditorBrushPresetLibraryError.fileTooLarge
        }
        return try replaceBrushPresetLibraryData(Data(contentsOf: url))
    }

    func chooseBrushPresetImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [Self.brushPresetContentType, .json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = L10n.text("imageEditor.action.brushPresetImport")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                do {
                    try self.importBrushPresetLibrary(from: url)
                } catch {
                    self.statusText = self.brushPresetLibraryErrorStatus(error)
                }
            }
        }
    }

    func chooseBrushPresetReplacementFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [Self.brushPresetContentType, .json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = L10n.text("imageEditor.action.brushPresetReplaceLibrary")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = L10n.text(
                    "imageEditor.brushPreset.replaceConfirmation.title"
                )
                alert.informativeText = L10n.format(
                    "imageEditor.brushPreset.replaceConfirmation.message",
                    self.customBrushPresets.count
                )
                alert.addButton(withTitle: L10n.text(
                    "imageEditor.action.brushPresetReplaceLibrary"
                ))
                alert.addButton(withTitle: L10n.text("imageEditor.action.cancel"))
                alert.buttons.first?.hasDestructiveAction = true
                guard alert.runModal() == .alertFirstButtonReturn else { return }
                do {
                    try self.replaceBrushPresetLibrary(from: url)
                } catch {
                    self.statusText = self.brushPresetLibraryErrorStatus(error)
                }
            }
        }
    }

    func confirmBrushPresetLibraryReset() {
        guard canResetCustomBrushPresetLibrary else {
            statusText = L10n.text("imageEditor.status.brushPresetLibraryResetUnavailable")
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.text(
            "imageEditor.brushPreset.resetConfirmation.title"
        )
        alert.informativeText = L10n.format(
            "imageEditor.brushPreset.resetConfirmation.message",
            customBrushPresets.count
        )
        alert.addButton(withTitle: L10n.text(
            "imageEditor.action.brushPresetResetLibrary"
        ))
        alert.addButton(withTitle: L10n.text("imageEditor.action.cancel"))
        alert.buttons.first?.hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        resetCustomBrushPresetLibrary()
    }

    @discardableResult
    func importDroppedBrushPresetLibrary(from urls: [URL]) -> Bool {
        guard let url = ImageEditorBrushPresetDropPolicy.acceptedURL(from: urls) else {
            return false
        }
        let didAccessSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            try importBrushPresetLibrary(from: url)
            return true
        } catch {
            statusText = brushPresetLibraryErrorStatus(error)
            return false
        }
    }

    func chooseBrushPresetExportFile(presetIDs: [String]? = nil) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [Self.brushPresetContentType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = brushPresetExportFilename(presetIDs: presetIDs)
        panel.prompt = L10n.text("imageEditor.action.brushPresetExport")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                do {
                    try self.exportBrushPresetLibrary(to: url, presetIDs: presetIDs)
                } catch {
                    self.statusText = self.brushPresetLibraryErrorStatus(error)
                }
            }
        }
    }

    private func uniqueImportedBrushPresetName(
        _ sourceName: String,
        existingNames: Set<String>
    ) -> String {
        let normalizedSource = ImageEditorBrushPreset.normalizedCustomName(sourceName)
            ?? L10n.text("imageEditor.brushPreset.untitled")
        guard existingNames.contains(normalizedSource) else { return normalizedSource }

        var sequence = 1
        while true {
            let suffix = sequence == 1
                ? L10n.text("imageEditor.brushPreset.copySuffix")
                : L10n.format("imageEditor.brushPreset.copySuffixIndexed", sequence)
            let availableBaseLength = max(
                0,
                ImageEditorBrushPreset.maximumCustomNameLength - suffix.count
            )
            let candidate = String(normalizedSource.prefix(availableBaseLength)) + suffix
            if !existingNames.contains(candidate) { return candidate }
            sequence += 1
        }
    }

    private func decodedBrushPresetLibrary(
        from data: Data
    ) throws -> ImageEditorBrushPresetLibrary {
        guard data.count <= ImageEditorBrushPresetLibrary.maximumFileSize else {
            throw ImageEditorBrushPresetLibraryError.fileTooLarge
        }
        let library: ImageEditorBrushPresetLibrary
        do {
            library = try JSONDecoder().decode(ImageEditorBrushPresetLibrary.self, from: data)
        } catch {
            throw ImageEditorBrushPresetLibraryError.invalidFile
        }
        guard library.formatVersion == ImageEditorBrushPresetLibrary.currentFormatVersion else {
            throw ImageEditorBrushPresetLibraryError.unsupportedFormatVersion
        }
        guard !library.presets.isEmpty else {
            throw ImageEditorBrushPresetLibraryError.emptyLibrary
        }
        return library
    }

    private func preparedBrushPresets(
        from sourcePresets: [ImageEditorBrushPreset],
        limit: Int,
        existingNames initialNames: Set<String>
    ) -> [ImageEditorBrushPreset] {
        var existingNames = initialNames
        return sourcePresets.prefix(max(0, limit)).map { sourcePreset in
            let sourceName = sourcePreset.normalizedCustomPreset.title
            let name = uniqueImportedBrushPresetName(
                sourceName,
                existingNames: existingNames
            )
            existingNames.insert(name)
            return sourcePreset.copyingCustomPreset(
                id: UUID().uuidString,
                name: name
            )
        }
    }

    private func brushPresetExportFilename(presetIDs: [String]?) -> String {
        let baseName: String
        if let id = presetIDs?.first,
           presetIDs?.count == 1,
           let preset = customBrushPresets.first(where: { $0.id == id }) {
            baseName = preset.title
        } else {
            baseName = L10n.text("imageEditor.brushPreset.libraryFilename")
        }
        let safeBaseName = baseName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
        return "\(safeBaseName).\(ImageEditorBrushPresetLibrary.fileExtension)"
    }

    private func brushPresetLibraryErrorStatus(_ error: Error) -> String {
        switch error as? ImageEditorBrushPresetLibraryError {
        case .fileTooLarge:
            return L10n.text("imageEditor.status.brushPresetFileTooLarge")
        case .unsupportedFormatVersion:
            return L10n.text("imageEditor.status.brushPresetUnsupportedVersion")
        case .emptyLibrary, .noMatchingPresets:
            return L10n.text("imageEditor.status.brushPresetLibraryEmpty")
        case .invalidFile, .none:
            return L10n.text("imageEditor.status.brushPresetFileInvalid")
        }
    }
}
