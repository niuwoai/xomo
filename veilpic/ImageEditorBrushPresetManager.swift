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
    let unselectedCount: Int
    let capacitySkippedCount: Int

    var skippedCount: Int {
        unselectedCount + capacitySkippedCount
    }
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
    let reservedTitles: Set<String>
}

struct ImageEditorBrushPresetLibraryInstallationPlanItem: Equatable {
    let sourceIndex: Int
    let sourceTitle: String
    let installedTitle: String

    var isRenamed: Bool {
        sourceTitle != installedTitle
    }
}

enum ImageEditorBrushPresetImportNamingPolicy {
    static func plannedItems(
        presetTitles: [String],
        selectedIndexes: IndexSet,
        capacity: Int,
        reservedTitles: Set<String>
    ) -> [ImageEditorBrushPresetLibraryInstallationPlanItem] {
        let normalizedIndexes = ImageEditorBrushPresetImportSelectionPolicy.normalizedSelection(
            selectedIndexes,
            presetCount: presetTitles.count,
            capacity: capacity
        )
        var occupiedTitles = reservedTitles
        return normalizedIndexes.map { sourceIndex in
            let sourceTitle = presetTitles[sourceIndex]
            let installedTitle = uniqueTitle(
                sourceTitle,
                occupiedTitles: occupiedTitles
            )
            occupiedTitles.insert(installedTitle)
            return ImageEditorBrushPresetLibraryInstallationPlanItem(
                sourceIndex: sourceIndex,
                sourceTitle: sourceTitle,
                installedTitle: installedTitle
            )
        }
    }

    private static func uniqueTitle(
        _ sourceTitle: String,
        occupiedTitles: Set<String>
    ) -> String {
        let normalizedSource = ImageEditorBrushPreset.normalizedCustomName(sourceTitle)
            ?? L10n.text("imageEditor.brushPreset.untitled")
        guard occupiedTitles.contains(normalizedSource) else { return normalizedSource }

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
            if !occupiedTitles.contains(candidate) { return candidate }
            sequence += 1
        }
    }
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

    static func matchingIndexes(
        presetTitles: [String],
        searchText: String
    ) -> IndexSet {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return IndexSet(integersIn: presetTitles.indices)
        }
        return IndexSet(presetTitles.indices.filter { index in
            presetTitles[index].range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        })
    }

    static func orderedIndexes(
        presetTitles: [String],
        matchingIndexes: IndexSet,
        sortOrder: ImageEditorBrushPresetSortOrder
    ) -> [Int] {
        let validIndexes = matchingIndexes.filter {
            $0 >= 0 && $0 < presetTitles.count
        }
        guard sortOrder != .catalog else { return Array(validIndexes) }
        return validIndexes.sorted { lhs, rhs in
            let comparison = presetTitles[lhs].compare(
                presetTitles[rhs],
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            if comparison == .orderedSame { return lhs < rhs }
            return sortOrder == .nameAscending
                ? comparison == .orderedAscending
                : comparison == .orderedDescending
        }
    }

    static func selectingAll(
        matchingIndexes: IndexSet,
        in selection: IndexSet,
        presetCount: Int,
        capacity: Int
    ) -> IndexSet {
        var updated = normalizedSelection(
            selection,
            presetCount: presetCount,
            capacity: capacity
        )
        for index in matchingIndexes where index >= 0 && index < presetCount {
            guard updated.count < max(0, capacity) else { break }
            updated.insert(index)
        }
        return updated
    }

    static func deselectingAll(
        matchingIndexes: IndexSet,
        in selection: IndexSet,
        presetCount: Int,
        capacity: Int
    ) -> IndexSet {
        var updated = normalizedSelection(
            selection,
            presetCount: presetCount,
            capacity: capacity
        )
        for index in matchingIndexes {
            updated.remove(index)
        }
        return updated
    }

    static func inverting(
        matchingIndexes: IndexSet,
        in selection: IndexSet,
        presetCount: Int,
        capacity: Int
    ) -> IndexSet {
        let validMatches = IndexSet(
            matchingIndexes.filter { $0 >= 0 && $0 < presetCount }
        )
        let normalized = normalizedSelection(
            selection,
            presetCount: presetCount,
            capacity: capacity
        )
        let originallySelectedMatches = normalized.intersection(validMatches)
        var updated = normalized.subtracting(originallySelectedMatches)
        for index in validMatches where !originallySelectedMatches.contains(index) {
            guard updated.count < max(0, capacity) else { break }
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

final class ImageEditorBrushPresetImportSelectionView: NSView {
    private let presetTitles: [String]
    private let reservedTitles: Set<String>
    private let presetCount: Int
    private let capacity: Int
    private let summaryLabel = NSTextField(labelWithString: "")
    private let searchField = NSSearchField()
    private let selectAllButton = NSButton()
    private let selectNoneButton = NSButton()
    private let invertSelectionButton = NSButton()
    private let sortOrderPopUpButton = NSPopUpButton()
    private let presetStack = NSStackView()
    private var presetButtons: [NSButton] = []
    private var sortOrder = ImageEditorBrushPresetSortOrder.catalog
    private(set) var selectedIndexes: IndexSet
    var onSelectionChange: ((IndexSet) -> Void)?

    init(inspection: ImageEditorBrushPresetLibraryInspection) {
        presetTitles = inspection.presetTitles
        reservedTitles = inspection.reservedTitles
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

        searchField.placeholderString = L10n.text(
            "imageEditor.brushPreset.importSelection.searchPlaceholder"
        )
        searchField.target = self
        searchField.action = #selector(searchPresets)
        searchField.sendsSearchStringImmediately = true
        searchField.identifier = NSUserInterfaceItemIdentifier(
            "image-editor-brush-preset-import-search"
        )
        searchField.frame = NSRect(x: 0, y: 222, width: 420, height: 24)
        addSubview(searchField)

        selectAllButton.title = L10n.text("imageEditor.action.selectAll")
        selectAllButton.target = self
        selectAllButton.action = #selector(selectAllPresets)
        selectAllButton.bezelStyle = .inline
        selectAllButton.controlSize = .small
        selectAllButton.frame = NSRect(x: 0, y: 194, width: 96, height: 24)
        addSubview(selectAllButton)

        selectNoneButton.title = L10n.text("imageEditor.action.selectNone")
        selectNoneButton.target = self
        selectNoneButton.action = #selector(selectNoPresets)
        selectNoneButton.bezelStyle = .inline
        selectNoneButton.controlSize = .small
        selectNoneButton.frame = NSRect(x: 102, y: 194, width: 96, height: 24)
        addSubview(selectNoneButton)

        invertSelectionButton.title = L10n.text("imageEditor.action.invertSelection")
        invertSelectionButton.target = self
        invertSelectionButton.action = #selector(invertVisiblePresets)
        invertSelectionButton.bezelStyle = .inline
        invertSelectionButton.controlSize = .small
        invertSelectionButton.frame = NSRect(x: 204, y: 194, width: 96, height: 24)
        addSubview(invertSelectionButton)

        sortOrderPopUpButton.addItems(
            withTitles: ImageEditorBrushPresetSortOrder.allCases.map(\.title)
        )
        sortOrderPopUpButton.selectItem(at: 0)
        sortOrderPopUpButton.target = self
        sortOrderPopUpButton.action = #selector(sortPresets)
        sortOrderPopUpButton.controlSize = .small
        sortOrderPopUpButton.toolTip = L10n.text("imageEditor.brushPreset.sortLabel")
        sortOrderPopUpButton.identifier = NSUserInterfaceItemIdentifier(
            "image-editor-brush-preset-import-sort"
        )
        sortOrderPopUpButton.frame = NSRect(x: 306, y: 194, width: 114, height: 24)
        addSubview(sortOrderPopUpButton)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 190))
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        presetStack.orientation = .vertical
        presetStack.alignment = .leading
        presetStack.spacing = 2
        presetStack.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        presetButtons = inspection.presetTitles.enumerated().map { index, title in
            let button = NSButton(
                checkboxWithTitle: selectionItemTitle(index: index, title: title),
                target: self,
                action: #selector(togglePreset(_:))
            )
            button.tag = index
            button.controlSize = .small
            button.lineBreakMode = .byTruncatingTail
            button.toolTip = title
            presetStack.addArrangedSubview(button)
            return button
        }
        scrollView.documentView = presetStack
        addSubview(scrollView)
        updateControls(notifySelection: false)
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
        selectedIndexes = ImageEditorBrushPresetImportSelectionPolicy.selectingAll(
            matchingIndexes: visibleIndexes,
            in: selectedIndexes,
            presetCount: presetCount,
            capacity: capacity
        )
        updateControls()
    }

    @objc private func selectNoPresets() {
        selectedIndexes = ImageEditorBrushPresetImportSelectionPolicy.deselectingAll(
            matchingIndexes: visibleIndexes,
            in: selectedIndexes,
            presetCount: presetCount,
            capacity: capacity
        )
        updateControls()
    }

    @objc private func invertVisiblePresets() {
        selectedIndexes = ImageEditorBrushPresetImportSelectionPolicy.inverting(
            matchingIndexes: visibleIndexes,
            in: selectedIndexes,
            presetCount: presetCount,
            capacity: capacity
        )
        updateControls()
    }

    @objc private func searchPresets() {
        updateControls(notifySelection: false)
    }

    @objc private func sortPresets() {
        let index = sortOrderPopUpButton.indexOfSelectedItem
        guard ImageEditorBrushPresetSortOrder.allCases.indices.contains(index) else {
            return
        }
        sortOrder = ImageEditorBrushPresetSortOrder.allCases[index]
        updateControls(notifySelection: false)
    }

    private var visibleIndexes: IndexSet {
        ImageEditorBrushPresetImportSelectionPolicy.matchingIndexes(
            presetTitles: presetTitles,
            searchText: searchField.stringValue
        )
    }

    private func selectionItemTitle(index: Int, title: String) -> String {
        L10n.format(
            "imageEditor.brushPreset.importSelection.item",
            index + 1,
            title
        )
    }

    private func updateControls(notifySelection: Bool = true) {
        let visibleIndexes = visibleIndexes
        let installationPlan = ImageEditorBrushPresetImportNamingPolicy.plannedItems(
            presetTitles: presetTitles,
            selectedIndexes: selectedIndexes,
            capacity: capacity,
            reservedTitles: reservedTitles
        )
        let planBySourceIndex = Dictionary(
            uniqueKeysWithValues: installationPlan.map { ($0.sourceIndex, $0) }
        )
        summaryLabel.stringValue = L10n.format(
            "imageEditor.brushPreset.importSelection.summary",
            selectedIndexes.count,
            presetCount,
            visibleIndexes.count,
            capacity
        )
        for button in presetButtons {
            let isSelected = selectedIndexes.contains(button.tag)
            let sourceTitle = presetTitles[button.tag]
            if let item = planBySourceIndex[button.tag], item.isRenamed {
                button.title = L10n.format(
                    "imageEditor.brushPreset.importSelection.renamedItem",
                    button.tag + 1,
                    sourceTitle,
                    item.installedTitle
                )
                button.toolTip = L10n.format(
                    "imageEditor.brushPreset.importSelection.renamedItem",
                    button.tag + 1,
                    sourceTitle,
                    item.installedTitle
                )
            } else {
                button.title = selectionItemTitle(index: button.tag, title: sourceTitle)
                button.toolTip = sourceTitle
            }
            button.state = isSelected ? .on : .off
            button.isEnabled = isSelected || selectedIndexes.count < capacity
            button.isHidden = !visibleIndexes.contains(button.tag)
        }
        arrangePresetButtons(visibleIndexes: visibleIndexes)
        let documentHeight = max(188, CGFloat(visibleIndexes.count * 24 + 12))
        presetStack.frame = NSRect(x: 0, y: 0, width: 400, height: documentHeight)
        selectAllButton.isEnabled = selectedIndexes.count < capacity
            && visibleIndexes.contains { !selectedIndexes.contains($0) }
        selectNoneButton.isEnabled = visibleIndexes.contains {
            selectedIndexes.contains($0)
        }
        invertSelectionButton.isEnabled = ImageEditorBrushPresetImportSelectionPolicy.inverting(
            matchingIndexes: visibleIndexes,
            in: selectedIndexes,
            presetCount: presetCount,
            capacity: capacity
        ) != selectedIndexes
        if notifySelection {
            onSelectionChange?(selectedIndexes)
        }
    }

    private func arrangePresetButtons(visibleIndexes: IndexSet) {
        let orderedVisibleIndexes = ImageEditorBrushPresetImportSelectionPolicy.orderedIndexes(
            presetTitles: presetTitles,
            matchingIndexes: visibleIndexes,
            sortOrder: sortOrder
        )
        let hiddenIndexes = presetTitles.indices.filter {
            !visibleIndexes.contains($0)
        }
        for button in presetButtons {
            presetStack.removeArrangedSubview(button)
            button.removeFromSuperview()
        }
        for index in orderedVisibleIndexes + hiddenIndexes {
            presetStack.addArrangedSubview(presetButtons[index])
        }
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
            unselectedCount: library.presets.count - selectedPresets.count,
            capacitySkippedCount: selectedPresets.count - importedPresets.count
        )
        statusText = brushPresetImportResultStatus(result, isReplacement: false)
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
            unselectedCount: library.presets.count - selectedPresets.count,
            capacitySkippedCount: selectedPresets.count - replacementPresets.count
        )
        statusText = brushPresetImportResultStatus(result, isReplacement: true)
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
        let reservedTitles: Set<String>
        switch mode {
        case .append:
            reservedTitles = Set(customBrushPresets.compactMap(\.name))
        case .replace:
            reservedTitles = []
        }
        return ImageEditorBrushPresetLibraryInspection(
            mode: mode,
            presetCount: library.presets.count,
            installableCount: installableCount,
            skippedCount: library.presets.count - installableCount,
            presetTitles: library.presets.map { $0.normalizedCustomPreset.title },
            reservedTitles: reservedTitles
        )
    }

    func brushPresetLibraryInstallationPlan(
        _ inspection: ImageEditorBrushPresetLibraryInspection,
        selectedIndexes: IndexSet? = nil
    ) throws -> [ImageEditorBrushPresetLibraryInstallationPlanItem] {
        if let selectedIndexes {
            guard !selectedIndexes.isEmpty,
                  selectedIndexes.allSatisfy({ $0 >= 0 && $0 < inspection.presetCount })
            else {
                throw ImageEditorBrushPresetLibraryError.invalidPresetSelection
            }
        }
        let indexes = selectedIndexes ?? ImageEditorBrushPresetImportSelectionPolicy.defaultSelection(
            presetCount: inspection.presetCount,
            capacity: inspection.installableCount
        )
        return ImageEditorBrushPresetImportNamingPolicy.plannedItems(
            presetTitles: inspection.presetTitles,
            selectedIndexes: indexes,
            capacity: inspection.installableCount,
            reservedTitles: inspection.reservedTitles
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
        let sourceTitles = sourcePresets.map { $0.normalizedCustomPreset.title }
        let plan = ImageEditorBrushPresetImportNamingPolicy.plannedItems(
            presetTitles: sourceTitles,
            selectedIndexes: IndexSet(integersIn: sourceTitles.indices),
            capacity: limit,
            reservedTitles: initialNames
        )
        return plan.map { item in
            sourcePresets[item.sourceIndex].copyingCustomPreset(
                id: UUID().uuidString,
                name: item.installedTitle
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

    private func brushPresetImportResultStatus(
        _ result: ImageEditorBrushPresetImportResult,
        isReplacement: Bool
    ) -> String {
        if result.unselectedCount > 0 {
            let key = isReplacement
                ? "imageEditor.status.brushPresetLibraryReplacedSelection"
                : "imageEditor.status.brushPresetImportedSelection"
            return L10n.format(
                key,
                result.importedCount,
                result.unselectedCount,
                result.capacitySkippedCount
            )
        }
        let key = isReplacement
            ? "imageEditor.status.brushPresetLibraryReplaced"
            : "imageEditor.status.brushPresetImported"
        return L10n.format(
            key,
            result.importedCount,
            result.capacitySkippedCount
        )
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
