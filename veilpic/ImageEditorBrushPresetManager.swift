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
    case invalidPresetSelection
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

enum ImageEditorBrushPresetLibraryInspectionMode: String, CaseIterable {
    case append
    case replace
}

struct ImageEditorBrushPresetLibraryInspection: Equatable {
    let mode: ImageEditorBrushPresetLibraryInspectionMode
    let presetCount: Int
    let installableCount: Int
    let skippedCount: Int
    let presetTitles: [String]
}

enum ImageEditorBrushPresetImportSelectionPolicy {
    static func defaultSelection(presetCount: Int, capacity: Int) -> IndexSet {
        IndexSet(integersIn: 0..<max(0, min(presetCount, capacity)))
    }

    static func normalizedSelection(
        _ selection: IndexSet,
        presetCount: Int,
        capacity: Int
    ) -> IndexSet {
        IndexSet(
            selection
                .filter { $0 >= 0 && $0 < presetCount }
                .prefix(max(0, capacity))
        )
    }

    static func toggling(
        index: Int,
        in selection: IndexSet,
        presetCount: Int,
        capacity: Int
    ) -> IndexSet {
        guard index >= 0, index < presetCount else {
            return normalizedSelection(
                selection,
                presetCount: presetCount,
                capacity: capacity
            )
        }
        var updated = normalizedSelection(
            selection,
            presetCount: presetCount,
            capacity: capacity
        )
        if updated.contains(index) {
            updated.remove(index)
        } else if updated.count < max(0, capacity) {
            updated.insert(index)
        }
        return updated
    }
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

private final class ImageEditorBrushPresetImportSelectionView: NSView {
    private let presetCount: Int
    private let capacity: Int
    private let summaryLabel = NSTextField(labelWithString: "")
    private var presetButtons: [NSButton] = []
    private(set) var selectedIndexes: IndexSet
    var onSelectionChange: ((IndexSet) -> Void)?

    init(inspection: ImageEditorBrushPresetLibraryInspection) {
        presetCount = inspection.presetTitles.count
        capacity = inspection.installableCount
        selectedIndexes = ImageEditorBrushPresetImportSelectionPolicy.defaultSelection(
            presetCount: inspection.presetTitles.count,
            capacity: inspection.installableCount
        )
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 280))

        summaryLabel.frame = NSRect(x: 0, y: 252, width: 420, height: 20)
        summaryLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        addSubview(summaryLabel)

        let selectAllButton = NSButton(
            title: L10n.text("imageEditor.action.selectAll"),
            target: self,
            action: #selector(selectAllPresets)
        )
        selectAllButton.bezelStyle = .inline
        selectAllButton.controlSize = .small
        selectAllButton.frame = NSRect(x: 0, y: 224, width: 96, height: 24)
        addSubview(selectAllButton)

        let selectNoneButton = NSButton(
            title: L10n.text("imageEditor.action.selectNone"),
            target: self,
            action: #selector(selectNoPresets)
        )
        selectNoneButton.bezelStyle = .inline
        selectNoneButton.controlSize = .small
        selectNoneButton.frame = NSRect(x: 102, y: 224, width: 96, height: 24)
        addSubview(selectNoneButton)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 220))
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        presetButtons = inspection.presetTitles.enumerated().map { index, title in
            let button = NSButton(
                checkboxWithTitle: L10n.format(
                    "imageEditor.brushPreset.importSelection.item",
                    index + 1,
                    title
                ),
                target: self,
                action: #selector(togglePreset(_:))
            )
            button.tag = index
            button.controlSize = .small
            button.lineBreakMode = .byTruncatingTail
            button.toolTip = title
            stack.addArrangedSubview(button)
            return button
        }
        let documentHeight = max(218, CGFloat(presetButtons.count * 24 + 12))
        stack.frame = NSRect(x: 0, y: 0, width: 400, height: documentHeight)
        scrollView.documentView = stack
        addSubview(scrollView)
        updateControls()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func togglePreset(_ sender: NSButton) {
        selectedIndexes = ImageEditorBrushPresetImportSelectionPolicy.toggling(
            index: sender.tag,
            in: selectedIndexes,
            presetCount: presetCount,
            capacity: capacity
        )
        updateControls()
    }

    @objc private func selectAllPresets() {
        selectedIndexes = ImageEditorBrushPresetImportSelectionPolicy.defaultSelection(
            presetCount: presetCount,
            capacity: capacity
        )
        updateControls()
    }

    @objc private func selectNoPresets() {
        selectedIndexes = []
        updateControls()
    }

    private func updateControls() {
        summaryLabel.stringValue = L10n.format(
            "imageEditor.brushPreset.importSelection.summary",
            selectedIndexes.count,
            presetCount,
            capacity
        )
        for button in presetButtons {
            let isSelected = selectedIndexes.contains(button.tag)
            button.state = isSelected ? .on : .off
            button.isEnabled = isSelected || selectedIndexes.count < capacity
        }
        onSelectionChange?(selectedIndexes)
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
    func importBrushPresetLibraryData(
        _ data: Data,
        selectedIndexes: IndexSet? = nil
    ) throws -> ImageEditorBrushPresetImportResult {
        let library = try decodedBrushPresetLibrary(from: data)
        let selectedPresets = try selectedBrushPresets(
            from: library,
            selectedIndexes: selectedIndexes
        )
        let availableCount = max(
            0,
            ImageEditorBrushPresetPreferences.maximumPresetCount - customBrushPresets.count
        )
        let importedPresets = preparedBrushPresets(
            from: selectedPresets,
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
        _ data: Data,
        selectedIndexes: IndexSet? = nil
    ) throws -> ImageEditorBrushPresetImportResult {
        let library = try decodedBrushPresetLibrary(from: data)
        let selectedPresets = try selectedBrushPresets(
            from: library,
            selectedIndexes: selectedIndexes
        )
        let replacementPresets = preparedBrushPresets(
            from: selectedPresets,
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

    func inspectBrushPresetLibraryData(
        _ data: Data,
        mode: ImageEditorBrushPresetLibraryInspectionMode = .replace
    ) throws -> ImageEditorBrushPresetLibraryInspection {
        let library = try decodedBrushPresetLibrary(from: data)
        let capacity: Int
        switch mode {
        case .append:
            capacity = max(
                0,
                ImageEditorBrushPresetPreferences.maximumPresetCount
                    - customBrushPresets.count
            )
        case .replace:
            capacity = ImageEditorBrushPresetPreferences.maximumPresetCount
        }
        let installableCount = min(library.presets.count, capacity)
        return ImageEditorBrushPresetLibraryInspection(
            mode: mode,
            presetCount: library.presets.count,
            installableCount: installableCount,
            skippedCount: library.presets.count - installableCount,
            presetTitles: library.presets.map { $0.normalizedCustomPreset.title }
        )
    }

    func exportBrushPresetLibrary(to url: URL, presetIDs: [String]? = nil) throws {
        try brushPresetLibraryData(presetIDs: presetIDs).write(to: url, options: .atomic)
        statusText = L10n.format("imageEditor.status.brushPresetExported", url.lastPathComponent)
    }

    @discardableResult
    func importBrushPresetLibrary(
        from url: URL,
        selectedIndexes: IndexSet? = nil
    ) throws -> ImageEditorBrushPresetImportResult {
        try importBrushPresetLibraryData(
            brushPresetLibraryArchiveData(from: url),
            selectedIndexes: selectedIndexes
        )
    }

    @discardableResult
    func replaceBrushPresetLibrary(
        from url: URL,
        selectedIndexes: IndexSet? = nil
    ) throws -> ImageEditorBrushPresetImportResult {
        try replaceBrushPresetLibraryData(
            brushPresetLibraryArchiveData(from: url),
            selectedIndexes: selectedIndexes
        )
    }

    func inspectBrushPresetLibrary(
        from url: URL,
        mode: ImageEditorBrushPresetLibraryInspectionMode = .replace
    ) throws -> ImageEditorBrushPresetLibraryInspection {
        try inspectBrushPresetLibraryData(
            brushPresetLibraryArchiveData(from: url),
            mode: mode
        )
    }

    func brushPresetLibraryArchiveData(from url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize,
           fileSize > ImageEditorBrushPresetLibrary.maximumFileSize {
            throw ImageEditorBrushPresetLibraryError.fileTooLarge
        }
        let data = try Data(contentsOf: url)
        guard data.count <= ImageEditorBrushPresetLibrary.maximumFileSize else {
            throw ImageEditorBrushPresetLibraryError.fileTooLarge
        }
        return data
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
                self.importBrushPresetLibraryWithConfirmation(from: url)
            }
        }
    }

    @discardableResult
    func importBrushPresetLibraryWithConfirmation(from url: URL) -> Bool {
        importBrushPresetLibraryWithConfirmation(from: url) { [weak self] url, inspection in
            self?.presentBrushPresetImportSelection(
                sourceURL: url,
                inspection: inspection
            )
        }
    }

    @discardableResult
    func importBrushPresetLibraryWithConfirmation(
        from url: URL,
        selectPresets: (URL, ImageEditorBrushPresetLibraryInspection) -> IndexSet?
    ) -> Bool {
        do {
            let data = try brushPresetLibraryArchiveData(from: url)
            let inspection = try inspectBrushPresetLibraryData(data, mode: .append)
            guard let selectedIndexes = selectPresets(url, inspection),
                  !selectedIndexes.isEmpty
            else { return false }
            try importBrushPresetLibraryData(
                data,
                selectedIndexes: selectedIndexes
            )
            return true
        } catch {
            statusText = brushPresetLibraryErrorStatus(error)
            return false
        }
    }

    private func presentBrushPresetImportSelection(
        sourceURL: URL,
        inspection: ImageEditorBrushPresetLibraryInspection
    ) -> IndexSet? {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.text(
            "imageEditor.brushPreset.importConfirmation.title"
        )
        alert.informativeText = L10n.format(
            "imageEditor.brushPreset.importConfirmation.message",
            sourceURL.lastPathComponent,
            inspection.presetCount,
            inspection.installableCount,
            inspection.skippedCount,
            customBrushPresets.count
        )
        alert.addButton(withTitle: L10n.text("imageEditor.action.brushPresetImport"))
        alert.addButton(withTitle: L10n.text("imageEditor.action.cancel"))
        let selectionView = ImageEditorBrushPresetImportSelectionView(
            inspection: inspection
        )
        alert.accessoryView = selectionView
        selectionView.onSelectionChange = { [weak alert] selection in
            alert?.buttons.first?.isEnabled = !selection.isEmpty
        }
        alert.buttons.first?.isEnabled = !selectionView.selectedIndexes.isEmpty
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return selectionView.selectedIndexes
    }

    @discardableResult
    func replaceBrushPresetLibraryWithConfirmation(from url: URL) -> Bool {
        replaceBrushPresetLibraryWithConfirmation(from: url) { [weak self] url, inspection in
            self?.presentBrushPresetReplacementSelection(
                sourceURL: url,
                inspection: inspection
            )
        }
    }

    @discardableResult
    func replaceBrushPresetLibraryWithConfirmation(
        from url: URL,
        selectPresets: (URL, ImageEditorBrushPresetLibraryInspection) -> IndexSet?
    ) -> Bool {
        do {
            let data = try brushPresetLibraryArchiveData(from: url)
            let inspection = try inspectBrushPresetLibraryData(data, mode: .replace)
            guard let selectedIndexes = selectPresets(url, inspection),
                  !selectedIndexes.isEmpty
            else { return false }
            try replaceBrushPresetLibraryData(
                data,
                selectedIndexes: selectedIndexes
            )
            return true
        } catch {
            statusText = brushPresetLibraryErrorStatus(error)
            return false
        }
    }

    private func presentBrushPresetReplacementSelection(
        sourceURL: URL,
        inspection: ImageEditorBrushPresetLibraryInspection
    ) -> IndexSet? {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.text(
            "imageEditor.brushPreset.replaceConfirmation.title"
        )
        alert.informativeText = L10n.format(
            "imageEditor.brushPreset.replaceConfirmation.message",
            sourceURL.lastPathComponent,
            inspection.presetCount,
            inspection.installableCount,
            inspection.skippedCount,
            customBrushPresets.count
        )
        alert.addButton(withTitle: L10n.text(
            "imageEditor.action.brushPresetReplaceLibrary"
        ))
        alert.addButton(withTitle: L10n.text("imageEditor.action.cancel"))
        alert.buttons.first?.hasDestructiveAction = true
        let selectionView = ImageEditorBrushPresetImportSelectionView(
            inspection: inspection
        )
        alert.accessoryView = selectionView
        selectionView.onSelectionChange = { [weak alert] selection in
            alert?.buttons.first?.isEnabled = !selection.isEmpty
        }
        alert.buttons.first?.isEnabled = !selectionView.selectedIndexes.isEmpty
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return selectionView.selectedIndexes
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
                self.replaceBrushPresetLibraryWithConfirmation(from: url)
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
        importDroppedBrushPresetLibrary(from: urls) { [weak self] url, inspection in
            self?.presentBrushPresetImportSelection(
                sourceURL: url,
                inspection: inspection
            )
        }
    }

    @discardableResult
    func importDroppedBrushPresetLibrary(
        from urls: [URL],
        selectPresets: (URL, ImageEditorBrushPresetLibraryInspection) -> IndexSet?
    ) -> Bool {
        guard let url = ImageEditorBrushPresetDropPolicy.acceptedURL(from: urls) else {
            return false
        }
        let didAccessSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return importBrushPresetLibraryWithConfirmation(
            from: url,
            selectPresets: selectPresets
        )
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

    private func selectedBrushPresets(
        from library: ImageEditorBrushPresetLibrary,
        selectedIndexes: IndexSet?
    ) throws -> [ImageEditorBrushPreset] {
        guard let selectedIndexes else { return library.presets }
        guard !selectedIndexes.isEmpty,
              selectedIndexes.allSatisfy({ $0 >= 0 && $0 < library.presets.count })
        else {
            throw ImageEditorBrushPresetLibraryError.invalidPresetSelection
        }
        return selectedIndexes.map { library.presets[$0] }
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
        case .invalidPresetSelection:
            return L10n.text("imageEditor.status.brushPresetSelectionInvalid")
        case .invalidFile, .none:
            return L10n.text("imageEditor.status.brushPresetFileInvalid")
        }
    }
}
