//
//  ImageEditorLayerStylePresetManager.swift
//  veilpic
//
//  Created by Codex on 2026/7/14.
//

import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum ImageEditorLayerStylePresetMoveDirection: String, CaseIterable {
    case top
    case up
    case down
    case bottom
}

enum ImageEditorLayerStylePresetLibraryError: Error, Equatable {
    case fileTooLarge
    case invalidFile
    case unsupportedFormatVersion
    case emptyLibrary
    case noMatchingPresets
}

struct ImageEditorLayerStylePresetLibrary: Codable, Equatable {
    static let currentFormatVersion = 1
    static let maximumFileSize = 5 * 1_024 * 1_024
    static let fileExtension = "xomostyles"

    let formatVersion: Int
    let presets: [ImageEditorLayerStylePreset]

    init(
        formatVersion: Int = currentFormatVersion,
        presets: [ImageEditorLayerStylePreset]
    ) {
        self.formatVersion = formatVersion
        self.presets = presets
    }
}

struct ImageEditorLayerStylePresetImportResult: Equatable {
    let importedCount: Int
    let skippedCount: Int
}

@MainActor
extension ImageEditorViewModel {
    static var layerStylePresetContentType: UTType {
        UTType(
            exportedAs: "im.some.xomo.layer-style-presets",
            conformingTo: .json
        )
    }

    @discardableResult
    func renameLayerStylePreset(id: String, name: String) -> Bool {
        guard let index = customLayerStylePresets.firstIndex(where: { $0.id == id }) else {
            statusText = L10n.text("imageEditor.status.layerStylePresetMissing")
            return false
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerStylePresetNameRequired")
            return false
        }
        let oldPreset = customLayerStylePresets[index]
        let renamed = ImageEditorLayerStylePreset(
            id: oldPreset.id,
            name: trimmed,
            style: oldPreset.style
        ).normalizedCustomPreset
        guard renamed != oldPreset else {
            statusText = L10n.format("imageEditor.status.layerStylePresetAlreadyNamed", renamed.title)
            return true
        }
        customLayerStylePresets[index] = renamed
        persistLayerStylePresetPreferences()
        statusText = L10n.format("imageEditor.status.layerStylePresetRenamed", renamed.title)
        return true
    }

    @discardableResult
    func moveLayerStylePreset(
        id: String,
        direction: ImageEditorLayerStylePresetMoveDirection
    ) -> Bool {
        guard let sourceIndex = customLayerStylePresets.firstIndex(where: { $0.id == id }) else {
            statusText = L10n.text("imageEditor.status.layerStylePresetMissing")
            return false
        }
        let lastIndex = customLayerStylePresets.index(before: customLayerStylePresets.endIndex)
        let destinationIndex: Int
        switch direction {
        case .top: destinationIndex = 0
        case .up: destinationIndex = max(0, sourceIndex - 1)
        case .down: destinationIndex = min(lastIndex, sourceIndex + 1)
        case .bottom: destinationIndex = lastIndex
        }
        guard sourceIndex != destinationIndex else { return true }

        let preset = customLayerStylePresets.remove(at: sourceIndex)
        customLayerStylePresets.insert(preset, at: destinationIndex)
        persistLayerStylePresetPreferences()
        statusText = L10n.format("imageEditor.status.layerStylePresetMoved", preset.title)
        return true
    }

    func layerStylePresetLibraryData(presetIDs: [String]? = nil) throws -> Data {
        let presets: [ImageEditorLayerStylePreset]
        if let presetIDs {
            let indexedPresets = Dictionary(
                uniqueKeysWithValues: availableLayerStylePresets.map { ($0.id, $0) }
            )
            presets = presetIDs.compactMap { indexedPresets[$0] }
        } else {
            presets = customLayerStylePresets
        }
        guard !presets.isEmpty else {
            throw ImageEditorLayerStylePresetLibraryError.noMatchingPresets
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(ImageEditorLayerStylePresetLibrary(presets: presets))
    }

    @discardableResult
    func importLayerStylePresetLibraryData(
        _ data: Data
    ) throws -> ImageEditorLayerStylePresetImportResult {
        guard data.count <= ImageEditorLayerStylePresetLibrary.maximumFileSize else {
            throw ImageEditorLayerStylePresetLibraryError.fileTooLarge
        }
        let library: ImageEditorLayerStylePresetLibrary
        do {
            library = try JSONDecoder().decode(ImageEditorLayerStylePresetLibrary.self, from: data)
        } catch {
            throw ImageEditorLayerStylePresetLibraryError.invalidFile
        }
        guard library.formatVersion == ImageEditorLayerStylePresetLibrary.currentFormatVersion else {
            throw ImageEditorLayerStylePresetLibraryError.unsupportedFormatVersion
        }
        guard !library.presets.isEmpty else {
            throw ImageEditorLayerStylePresetLibraryError.emptyLibrary
        }

        var importedCount = 0
        var skippedCount = 0
        for sourcePreset in library.presets {
            guard customLayerStylePresets.count < ImageEditorLayerStylePresetPreferences.maximumPresetCount else {
                skippedCount += 1
                continue
            }
            let normalized = sourcePreset.normalizedCustomPreset
            let isDuplicate = customLayerStylePresets.contains {
                $0.name == normalized.name && $0.style == normalized.style
            }
            guard !isDuplicate else {
                skippedCount += 1
                continue
            }
            customLayerStylePresets.append(
                ImageEditorLayerStylePreset(
                    id: UUID().uuidString,
                    name: normalized.name,
                    style: normalized.style
                )
            )
            importedCount += 1
        }
        if importedCount > 0 {
            persistLayerStylePresetPreferences()
        }
        statusText = L10n.format(
            "imageEditor.status.layerStylePresetImported",
            importedCount,
            skippedCount
        )
        return ImageEditorLayerStylePresetImportResult(
            importedCount: importedCount,
            skippedCount: skippedCount
        )
    }

    func exportLayerStylePresetLibrary(to url: URL, presetIDs: [String]? = nil) throws {
        let data = try layerStylePresetLibraryData(presetIDs: presetIDs)
        try data.write(to: url, options: .atomic)
        statusText = L10n.format(
            "imageEditor.status.layerStylePresetExported",
            url.lastPathComponent
        )
    }

    @discardableResult
    func importLayerStylePresetLibrary(from url: URL) throws -> ImageEditorLayerStylePresetImportResult {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize,
           fileSize > ImageEditorLayerStylePresetLibrary.maximumFileSize {
            throw ImageEditorLayerStylePresetLibraryError.fileTooLarge
        }
        return try importLayerStylePresetLibraryData(Data(contentsOf: url))
    }

    func chooseLayerStylePresetImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [Self.layerStylePresetContentType, .json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = L10n.text("imageEditor.action.layerStylePresetImport")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                do {
                    try self.importLayerStylePresetLibrary(from: url)
                } catch {
                    self.statusText = self.layerStylePresetLibraryErrorStatus(error)
                }
            }
        }
    }

    func chooseLayerStylePresetExportFile(presetIDs: [String]? = nil) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [Self.layerStylePresetContentType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = layerStylePresetExportFilename(presetIDs: presetIDs)
        panel.prompt = L10n.text("imageEditor.action.layerStylePresetExport")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                do {
                    try self.exportLayerStylePresetLibrary(to: url, presetIDs: presetIDs)
                } catch {
                    self.statusText = self.layerStylePresetLibraryErrorStatus(error)
                }
            }
        }
    }

    private func layerStylePresetExportFilename(presetIDs: [String]?) -> String {
        let baseName: String
        if let id = presetIDs?.first,
           presetIDs?.count == 1,
           let preset = customLayerStylePresets.first(where: { $0.id == id }) {
            baseName = preset.title
        } else {
            baseName = L10n.text("imageEditor.layerStylePreset.libraryFilename")
        }
        let safeBaseName = baseName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
        return "\(safeBaseName).\(ImageEditorLayerStylePresetLibrary.fileExtension)"
    }

    private func layerStylePresetLibraryErrorStatus(_ error: Error) -> String {
        switch error as? ImageEditorLayerStylePresetLibraryError {
        case .fileTooLarge:
            return L10n.text("imageEditor.status.layerStylePresetFileTooLarge")
        case .unsupportedFormatVersion:
            return L10n.text("imageEditor.status.layerStylePresetUnsupportedVersion")
        case .emptyLibrary, .noMatchingPresets:
            return L10n.text("imageEditor.status.layerStylePresetLibraryEmpty")
        case .invalidFile, .none:
            return L10n.text("imageEditor.status.layerStylePresetFileInvalid")
        }
    }
}

struct ImageEditorLayerStylePresetManager: View {
    @ObservedObject var viewModel: ImageEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPresetID: String?
    @State private var nameDraft = ""
    @State private var searchText = ""
    @State private var scope = ImageEditorLayerStylePresetScope.all
    @State private var collection = ImageEditorLayerStylePresetCollection.all

    private var query: ImageEditorLayerStylePresetQuery {
        ImageEditorLayerStylePresetQuery(
            searchText: searchText,
            scope: scope,
            collection: collection,
            favoriteIDs: Set(viewModel.favoriteLayerStylePresetIDs),
            recentIDs: viewModel.recentLayerStylePresetIDs
        )
    }

    private var filteredPresets: [ImageEditorLayerStylePreset] {
        query.filter(viewModel.availableLayerStylePresets)
    }

    private var filteredBuiltInPresets: [ImageEditorLayerStylePreset] {
        filteredPresets.filter(\.isBuiltIn)
    }

    private var filteredCustomPresets: [ImageEditorLayerStylePreset] {
        filteredPresets.filter { !$0.isBuiltIn }
    }

    private var selectedPreset: ImageEditorLayerStylePreset? {
        guard let selectedPresetID else { return nil }
        return viewModel.layerStylePreset(id: selectedPresetID)
    }

    private var selectedPresetIndex: Int? {
        viewModel.customLayerStylePresets.firstIndex { $0.id == selectedPresetID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("imageEditor.layerStylePreset.managerTitle"))
                        .font(.system(size: 16, weight: .bold))
                    Text(L10n.text("imageEditor.layerStylePreset.managerSubtitle"))
                        .font(.system(size: 11))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                }
                Spacer()
                Text(L10n.format(
                    "imageEditor.layerStylePreset.count",
                    viewModel.customLayerStylePresets.count,
                    ImageEditorLayerStylePresetPreferences.maximumPresetCount
                ))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }
            .padding(16)

            Divider()

            HStack(spacing: 0) {
                presetList
                    .frame(width: 250)
                Divider()
                presetInspector
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
            footer
                .padding(12)
        }
        .frame(width: 640, height: 450)
        .background(Color(nsColor: ImageEditorTheme.panel))
        .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
        .onAppear(perform: selectInitialPreset)
        .onChange(of: selectedPresetID) { _ in syncNameDraft() }
        .onChange(of: viewModel.customLayerStylePresets) { _ in repairSelection() }
        .onChange(of: viewModel.favoriteLayerStylePresetIDs) { _ in repairSelection() }
        .onChange(of: viewModel.recentLayerStylePresetIDs) { _ in repairSelection() }
        .onChange(of: searchText) { _ in repairSelection() }
        .onChange(of: scope) { _ in repairSelection() }
        .onChange(of: collection) { _ in repairSelection() }
    }

    private var presetList: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                TextField(
                    L10n.text("imageEditor.layerStylePreset.searchPlaceholder"),
                    text: $searchText
                )
                .textFieldStyle(.plain)
                .accessibilityIdentifier("image-editor-layer-style-preset-search")
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            Picker(L10n.text("imageEditor.layerStylePreset.scopeLabel"), selection: $scope) {
                ForEach(ImageEditorLayerStylePresetScope.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .focusable(false)
            .accessibilityIdentifier("image-editor-layer-style-preset-scope")

            Picker(
                L10n.text("imageEditor.layerStylePreset.collectionLabel"),
                selection: $collection
            ) {
                ForEach(ImageEditorLayerStylePresetCollection.allCases) { option in
                    Label(option.title, systemImage: option.symbolName)
                        .labelStyle(.iconOnly)
                        .tag(option)
                        .help(option.title)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .focusable(false)
            .accessibilityIdentifier("image-editor-layer-style-preset-collection")

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 5) {
                    if filteredPresets.isEmpty {
                        Text(L10n.text(emptyListMessageKey))
                            .font(.system(size: 11))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    } else if collection != .all {
                        presetSectionTitle(
                            collection == .favorites
                                ? "imageEditor.layerStylePreset.favoriteSection"
                                : "imageEditor.layerStylePreset.recentSection"
                        )
                        ForEach(filteredPresets) { preset in
                            presetRow(preset)
                        }
                    } else {
                        if !filteredBuiltInPresets.isEmpty {
                            presetSectionTitle("imageEditor.layerStylePreset.builtInSection")
                            ForEach(filteredBuiltInPresets) { preset in
                                presetRow(preset)
                            }
                        }
                        if !filteredCustomPresets.isEmpty {
                            presetSectionTitle("imageEditor.layerStylePreset.customSection")
                            ForEach(filteredCustomPresets) { preset in
                                presetRow(preset)
                            }
                        } else if scope != .builtIn,
                                  searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                  viewModel.customLayerStylePresets.isEmpty {
                            presetSectionTitle("imageEditor.layerStylePreset.customSection")
                            Text(L10n.text("imageEditor.layerStylePreset.empty"))
                                .font(.system(size: 11))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            Text(L10n.format(
                "imageEditor.layerStylePreset.showingCount",
                filteredPresets.count,
                viewModel.availableLayerStylePresets.count
            ))
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(10)
        .background(Color.black.opacity(0.12))
    }

    @ViewBuilder
    private var presetInspector: some View {
        if let preset = selectedPreset {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    ImageEditorLayerStylePresetThumbnail(preset: preset, width: 120, height: 78)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(preset.title)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(2)
                        Text(L10n.text(
                            preset.isBuiltIn
                                ? "imageEditor.layerStylePreset.builtInBadge"
                                : "imageEditor.layerStylePreset.customBadge"
                        ))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    }
                }

                if !preset.isBuiltIn, let index = selectedPresetIndex {
                    customPresetControls(index: index)
                }

                Divider()
                presetSummary(preset)
                Spacer(minLength: 0)

                HStack {
                    Button {
                        viewModel.setLayerStylePresetFavorite(
                            id: preset.id,
                            isFavorite: !viewModel.isFavoriteLayerStylePreset(id: preset.id)
                        )
                    } label: {
                        Label(
                            L10n.text(
                                viewModel.isFavoriteLayerStylePreset(id: preset.id)
                                    ? "imageEditor.action.layerStylePresetUnfavorite"
                                    : "imageEditor.action.layerStylePresetFavorite"
                            ),
                            systemImage: viewModel.isFavoriteLayerStylePreset(id: preset.id)
                                ? "star.fill"
                                : "star"
                        )
                    }
                    .focusable(false)
                    Button(L10n.text("imageEditor.action.layerStylePresetApply")) {
                        viewModel.applyLayerStylePreset(preset)
                    }
                    .focusable(false)
                    .disabled(!viewModel.canApplyLayerStylePreset)
                    Button(L10n.text("imageEditor.action.layerStylePresetExportSelected")) {
                        viewModel.chooseLayerStylePresetExportFile(presetIDs: [preset.id])
                    }
                    .focusable(false)
                    Spacer()
                    if preset.isBuiltIn {
                        Button(L10n.text("imageEditor.action.layerStylePresetDuplicate")) {
                            if let copy = viewModel.duplicateLayerStylePresetToCustom(preset) {
                                selectedPresetID = copy.id
                            }
                        }
                        .focusable(false)
                    } else {
                        Button(L10n.text("imageEditor.action.layerStylePresetDelete"), role: .destructive) {
                            viewModel.deleteLayerStylePreset(preset)
                        }
                        .focusable(false)
                    }
                }
            }
            .padding(16)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.system(size: 28))
                Text(L10n.text("imageEditor.layerStylePreset.managerEmpty"))
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func presetSectionTitle(_ key: String) -> some View {
        Text(L10n.text(key))
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            .textCase(.uppercase)
            .padding(.horizontal, 4)
            .padding(.top, 5)
    }

    private func presetRow(_ preset: ImageEditorLayerStylePreset) -> some View {
        HStack(spacing: 4) {
            Button {
                selectedPresetID = preset.id
            } label: {
                HStack(spacing: 8) {
                    ImageEditorLayerStylePresetThumbnail(preset: preset, width: 40, height: 26)
                    Text(preset.title)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if viewModel.activeLayerStylePreset?.id == preset.id {
                        Image(systemName: "checkmark")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)

            Button {
                viewModel.setLayerStylePresetFavorite(
                    id: preset.id,
                    isFavorite: !viewModel.isFavoriteLayerStylePreset(id: preset.id)
                )
            } label: {
                Image(systemName: viewModel.isFavoriteLayerStylePreset(id: preset.id) ? "star.fill" : "star")
                    .foregroundStyle(
                        viewModel.isFavoriteLayerStylePreset(id: preset.id)
                            ? Color.yellow.opacity(0.9)
                            : Color(nsColor: ImageEditorTheme.mutedText)
                    )
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(L10n.text(
                viewModel.isFavoriteLayerStylePreset(id: preset.id)
                    ? "imageEditor.action.layerStylePresetUnfavorite"
                    : "imageEditor.action.layerStylePresetFavorite"
            ))
            .accessibilityIdentifier("image-editor-layer-style-preset-favorite-\(preset.id)")
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background(
            selectedPresetID == preset.id
                ? Color.accentColor.opacity(0.72)
                : Color.white.opacity(0.05)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var emptyListMessageKey: String {
        let hasSearch = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasSearch { return "imageEditor.layerStylePreset.noResults" }
        switch collection {
        case .favorites:
            return "imageEditor.layerStylePreset.noFavorites"
        case .recent:
            return "imageEditor.layerStylePreset.noRecent"
        case .all:
            return scope == .custom && viewModel.customLayerStylePresets.isEmpty
                ? "imageEditor.layerStylePreset.empty"
                : "imageEditor.layerStylePreset.noResults"
        }
    }

    private func customPresetControls(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("imageEditor.layerStylePreset.name"))
                .font(.system(size: 11, weight: .semibold))
            HStack(spacing: 8) {
                TextField(L10n.text("imageEditor.layerStylePreset.namePlaceholder"), text: $nameDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        renameSelectedPreset()
                    }
                Button(L10n.text("imageEditor.action.layerStylePresetRename")) {
                    renameSelectedPreset()
                }
                .focusable(false)
                .disabled(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text(L10n.text("imageEditor.layerStylePreset.order"))
                .font(.system(size: 11, weight: .semibold))
            HStack(spacing: 8) {
                managerButton("imageEditor.action.layerTop", symbol: "arrow.up.to.line") {
                    moveSelectedPreset(.top)
                }
                .disabled(index == 0)
                managerButton("imageEditor.action.layerUp", symbol: "arrow.up") {
                    moveSelectedPreset(.up)
                }
                .disabled(index == 0)
                managerButton("imageEditor.action.layerDown", symbol: "arrow.down") {
                    moveSelectedPreset(.down)
                }
                .disabled(index == viewModel.customLayerStylePresets.count - 1)
                managerButton("imageEditor.action.layerBottom", symbol: "arrow.down.to.line") {
                    moveSelectedPreset(.bottom)
                }
                .disabled(index == viewModel.customLayerStylePresets.count - 1)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button(L10n.text("imageEditor.action.layerStylePresetCreate")) {
                if let preset = viewModel.createLayerStylePresetFromSelectedLayer() {
                    selectedPresetID = preset.id
                }
            }
            .focusable(false)
            .disabled(!viewModel.canCreateLayerStylePreset)

            Button(L10n.text("imageEditor.action.layerStylePresetImport")) {
                viewModel.chooseLayerStylePresetImportFile()
            }
            .focusable(false)

            Button(L10n.text("imageEditor.action.layerStylePresetExportAll")) {
                viewModel.chooseLayerStylePresetExportFile()
            }
            .focusable(false)
            .disabled(viewModel.customLayerStylePresets.isEmpty)

            Spacer()
            Button(L10n.text("action.done")) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func presetSummary(_ preset: ImageEditorLayerStylePreset) -> some View {
        let style = preset.layerStyle
        let effects = stylePresetEffectTitles(style)
        return VStack(alignment: .leading, spacing: 7) {
            Text(L10n.text("imageEditor.layerStylePreset.summary"))
                .font(.system(size: 11, weight: .semibold))
            Text(effects.isEmpty ? L10n.text("imageEditor.layerStylePreset.noEffects") : effects.joined(separator: " · "))
                .font(.system(size: 11))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.format(
                "imageEditor.properties.layerEffectScaleValue",
                Int((style.effectScale * 100).rounded())
            ))
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
        }
    }

    private func stylePresetEffectTitles(_ style: ImageEditorLayerStyle) -> [String] {
        [
            style.strokeEnabled ? L10n.text("imageEditor.action.layerStroke") : nil,
            style.shadowEnabled ? L10n.text("imageEditor.action.layerShadow") : nil,
            style.innerShadowEnabled ? L10n.text("imageEditor.action.layerInnerShadow") : nil,
            style.outerGlowEnabled ? L10n.text("imageEditor.action.layerOuterGlow") : nil,
            style.innerGlowEnabled ? L10n.text("imageEditor.action.layerInnerGlow") : nil,
            style.colorOverlayEnabled ? L10n.text("imageEditor.action.layerColorOverlay") : nil,
            style.gradientOverlayEnabled ? L10n.text("imageEditor.action.layerGradientOverlay") : nil,
            style.patternOverlayEnabled ? L10n.text("imageEditor.action.layerPatternOverlay") : nil,
            style.satinEnabled ? L10n.text("imageEditor.action.layerSatin") : nil,
            style.bevelEnabled ? L10n.text("imageEditor.action.layerBevel") : nil
        ].compactMap { $0 }
    }

    private func managerButton(
        _ key: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(L10n.text(key), systemImage: symbol)
                .labelStyle(.iconOnly)
        }
        .focusable(false)
        .help(L10n.text(key))
    }

    private func selectInitialPreset() {
        selectedPresetID = query.repairedSelectionID(
            viewModel.activeLayerStylePreset?.id,
            in: viewModel.availableLayerStylePresets
        )
        syncNameDraft()
    }

    private func repairSelection() {
        selectedPresetID = query.repairedSelectionID(
            selectedPresetID,
            in: viewModel.availableLayerStylePresets
        )
        syncNameDraft()
    }

    private func syncNameDraft() {
        nameDraft = selectedPreset?.title ?? ""
    }

    private func renameSelectedPreset() {
        guard let id = selectedPresetID else { return }
        if viewModel.renameLayerStylePreset(id: id, name: nameDraft) {
            syncNameDraft()
        }
    }

    private func moveSelectedPreset(_ direction: ImageEditorLayerStylePresetMoveDirection) {
        guard let id = selectedPresetID else { return }
        viewModel.moveLayerStylePreset(id: id, direction: direction)
    }
}
