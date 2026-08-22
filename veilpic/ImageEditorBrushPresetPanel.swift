//
//  ImageEditorBrushPresetPanel.swift
//  veilpic
//
//  Created by Codex on 2026/8/22.
//

import SwiftUI

struct ImageEditorBrushPresetManager: View {
    @ObservedObject var viewModel: ImageEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPresetID: String?
    @State private var selectedPresetIDs: Set<String> = []
    @State private var selectionAnchorID: String?
    @State private var nameDraft = ""
    @State private var searchText = ""
    @State private var scope = ImageEditorBrushPresetScope.all
    @State private var collection = ImageEditorBrushPresetCollection.all
    @State private var layout = ImageEditorBrushPresetPanelLayout.load()
    @State private var gridDensity = ImageEditorBrushPresetGridDensity.load()
    @State private var sortOrder = ImageEditorBrushPresetSortOrder.load()
    @State private var isImportDropTargeted = false
    @State private var reorderDropTargetID: String?
    @FocusState private var isNameFieldFocused: Bool

    private var query: ImageEditorBrushPresetQuery {
        ImageEditorBrushPresetQuery(
            searchText: searchText,
            scope: scope,
            collection: collection,
            sortOrder: sortOrder,
            favoriteIDs: Set(viewModel.favoriteBrushPresetIDs),
            recentIDs: viewModel.recentBrushPresetIDs
        )
    }

    private var filteredPresets: [ImageEditorBrushPreset] {
        query.presented(viewModel.brushPresets)
    }

    private var filteredBuiltInPresets: [ImageEditorBrushPreset] {
        filteredPresets.filter(\.isBuiltIn)
    }

    private var filteredCustomPresets: [ImageEditorBrushPreset] {
        filteredPresets.filter { !$0.isBuiltIn }
    }

    private var exportableVisibleCustomPresetIDs: [String] {
        query.exportableCustomPresetIDs(in: viewModel.brushPresets)
    }

    private var exportableSelectedCustomPresetIDs: [String] {
        query.exportableSelectedCustomPresetIDs(
            selectedPresetIDs,
            in: viewModel.brushPresets
        )
    }

    private var selectedVisiblePresetIDs: [String] {
        filteredPresets
            .filter { selectedPresetIDs.contains($0.id) }
            .map(\.id)
    }

    private var selectedFavoriteCount: Int {
        let favoriteIDs = Set(viewModel.favoriteBrushPresetIDs)
        return selectedVisiblePresetIDs.count(where: favoriteIDs.contains)
    }

    private var selectedPreset: ImageEditorBrushPreset? {
        guard let selectedPresetID else { return nil }
        return viewModel.brushPresets.first { $0.id == selectedPresetID }
    }

    private var selectedCustomIndex: Int? {
        viewModel.customBrushPresets.firstIndex { $0.id == selectedPresetID }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(16)
            Divider()
            HStack(spacing: 0) {
                presetList
                    .frame(width: 280)
                Divider()
                presetInspector
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            footer
                .padding(12)
        }
        .frame(width: 680, height: 470)
        .background(Color(nsColor: ImageEditorTheme.panel))
        .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
        .dropDestination(for: URL.self) { urls, _ in
            let didImport = viewModel.importDroppedBrushPresetLibrary(from: urls)
            if didImport {
                selectOnly(viewModel.selectedBrushPreset?.id)
            }
            return didImport
        } isTargeted: { isTargeted in
            isImportDropTargeted = isTargeted
        }
        .overlay {
            if isImportDropTargeted {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 2)
                    }
                    .overlay {
                        Label(
                            L10n.text("imageEditor.brushPreset.dropTarget"),
                            systemImage: "tray.and.arrow.down.fill"
                        )
                        .font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("image-editor-brush-preset-drop-target")
            }
        }
        .onAppear(perform: selectInitialPreset)
        .onChange(of: selectedPresetID) { _ in syncNameDraft() }
        .onChange(of: viewModel.customBrushPresets) { _ in repairSelection() }
        .onChange(of: viewModel.favoriteBrushPresetIDs) { _ in repairSelection() }
        .onChange(of: viewModel.recentBrushPresetIDs) { _ in repairSelection() }
        .onChange(of: searchText) { _ in repairSelection() }
        .onChange(of: scope) { _ in repairSelection() }
        .onChange(of: collection) { _ in
            reorderDropTargetID = nil
            repairSelection()
        }
        .onChange(of: layout) { layout in layout.save() }
        .onChange(of: gridDensity) { gridDensity in gridDensity.save() }
        .onChange(of: sortOrder) { sortOrder in
            reorderDropTargetID = nil
            sortOrder.save()
            repairSelection()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text("imageEditor.brushPreset.managerTitle"))
                    .font(.system(size: 16, weight: .bold))
                Text(L10n.text("imageEditor.brushPreset.managerSubtitle"))
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }
            Spacer()
            Text(L10n.format(
                "imageEditor.brushPreset.count",
                viewModel.customBrushPresets.count,
                ImageEditorBrushPresetPreferences.maximumPresetCount
            ))
            .font(.system(size: 11).monospacedDigit())
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
        }
    }

    private var presetList: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                TextField(
                    L10n.text("imageEditor.brushPreset.searchPlaceholder"),
                    text: $searchText
                )
                .textFieldStyle(.plain)
                .accessibilityIdentifier("image-editor-brush-preset-search")
                .help(L10n.text("imageEditor.brushPreset.searchHelp"))
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            Picker(L10n.text("imageEditor.brushPreset.scopeLabel"), selection: $scope) {
                ForEach(ImageEditorBrushPresetScope.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .focusable(false)
            .accessibilityIdentifier("image-editor-brush-preset-scope")

            Picker(L10n.text("imageEditor.brushPreset.collectionLabel"), selection: $collection) {
                ForEach(ImageEditorBrushPresetCollection.allCases) { option in
                    Label(option.title, systemImage: option.symbolName)
                        .labelStyle(.iconOnly)
                        .tag(option)
                        .help(option.title)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .focusable(false)
            .accessibilityIdentifier("image-editor-brush-preset-collection")

            ScrollView {
                if layout == .list {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        presetRows
                    }
                    .padding(.horizontal, 2)
                } else {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        presetGridRows
                    }
                    .padding(.horizontal, 2)
                }
            }

            HStack(spacing: 8) {
                Text(L10n.format(
                    "imageEditor.brushPreset.showingCount",
                    filteredPresets.count,
                    viewModel.brushPresets.count
                ))
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                Spacer(minLength: 0)

                Menu {
                    Button(L10n.text("imageEditor.action.brushPresetSelectAllVisible")) {
                        selectAllVisiblePresets()
                    }
                    .disabled(
                        filteredPresets.isEmpty
                            || selectedPresetIDs == Set(filteredPresets.map(\.id))
                    )

                    Button(L10n.text("imageEditor.action.brushPresetDeselectAll")) {
                        deselectAllPresets()
                    }
                    .disabled(selectedPresetIDs.isEmpty)

                    Button(L10n.text("imageEditor.action.brushPresetInvertVisibleSelection")) {
                        invertVisiblePresetSelection()
                    }
                    .disabled(filteredPresets.isEmpty)
                } label: {
                    Image(systemName: "checklist")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .focusable(false)
                .help(L10n.text("imageEditor.action.brushPresetSelectionMenu"))
                .accessibilityLabel(L10n.text("imageEditor.action.brushPresetSelectionMenu"))
                .accessibilityIdentifier("image-editor-brush-preset-selection-menu")

                Menu {
                    ForEach(ImageEditorBrushPresetSortOrder.allCases) { option in
                        Button {
                            sortOrder = option
                        } label: {
                            Label(
                                option.title,
                                systemImage: sortOrder == option ? "checkmark" : option.symbolName
                            )
                        }
                    }
                } label: {
                    Image(systemName: sortOrder.symbolName)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .focusable(false)
                .help(sortOrder.title)
                .accessibilityLabel(L10n.text("imageEditor.brushPreset.sortLabel"))
                .accessibilityValue(sortOrder.title)
                .accessibilityIdentifier("image-editor-brush-preset-sort")

                if layout == .grid {
                    Menu {
                        ForEach(ImageEditorBrushPresetGridDensity.allCases) { option in
                            Button {
                                gridDensity = option
                            } label: {
                                Label(
                                    option.title,
                                    systemImage: gridDensity == option
                                        ? "checkmark"
                                        : option.symbolName
                                )
                            }
                        }
                    } label: {
                        Image(systemName: gridDensity.symbolName)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .focusable(false)
                    .help(gridDensity.title)
                    .accessibilityLabel(L10n.text("imageEditor.brushPreset.gridDensityLabel"))
                    .accessibilityValue(gridDensity.title)
                    .accessibilityIdentifier("image-editor-brush-preset-grid-density")
                }

                Picker(L10n.text("imageEditor.brushPreset.layoutLabel"), selection: $layout) {
                    ForEach(ImageEditorBrushPresetPanelLayout.allCases) { option in
                        Label(option.title, systemImage: option.symbolName)
                            .labelStyle(.iconOnly)
                            .tag(option)
                            .help(option.title)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .focusable(false)
                .frame(width: 66)
                .accessibilityIdentifier("image-editor-brush-preset-layout")
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.12))
    }

    @ViewBuilder
    private var presetRows: some View {
        if filteredPresets.isEmpty {
            Text(L10n.text(emptyListMessageKey))
                .font(.system(size: 11))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        } else if collection != .all {
            presetSectionTitle(
                collection == .favorites
                    ? "imageEditor.brushPreset.favoriteSection"
                    : "imageEditor.brushPreset.recentSection"
            )
            ForEach(filteredPresets) { preset in
                presetRow(preset)
            }
        } else {
            if !filteredBuiltInPresets.isEmpty {
                presetSectionTitle("imageEditor.brushPreset.builtInSection")
                ForEach(filteredBuiltInPresets) { preset in
                    presetRow(preset)
                }
            }
            if !filteredCustomPresets.isEmpty {
                presetSectionTitle("imageEditor.brushPreset.customSection")
                ForEach(filteredCustomPresets) { preset in
                    presetRow(preset)
                }
            }
        }
    }

    @ViewBuilder
    private var presetGridRows: some View {
        if filteredPresets.isEmpty {
            Text(L10n.text(emptyListMessageKey))
                .font(.system(size: 11))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        } else if collection != .all {
            presetSectionTitle(
                collection == .favorites
                    ? "imageEditor.brushPreset.favoriteSection"
                    : "imageEditor.brushPreset.recentSection"
            )
            LazyVGrid(columns: presetGridColumns, spacing: 6) {
                ForEach(filteredPresets) { preset in
                    presetTile(preset)
                }
            }
        } else {
            if !filteredBuiltInPresets.isEmpty {
                presetSectionTitle("imageEditor.brushPreset.builtInSection")
                LazyVGrid(columns: presetGridColumns, spacing: 6) {
                    ForEach(filteredBuiltInPresets) { preset in
                        presetTile(preset)
                    }
                }
            }
            if !filteredCustomPresets.isEmpty {
                presetSectionTitle("imageEditor.brushPreset.customSection")
                LazyVGrid(columns: presetGridColumns, spacing: 6) {
                    ForEach(filteredCustomPresets) { preset in
                        presetTile(preset)
                    }
                }
            }
        }
    }

    private var presetGridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 6),
            count: gridDensity.columnCount
        )
    }

    @ViewBuilder
    private var presetInspector: some View {
        if selectedPresetIDs.count > 1 {
            multipleSelectionInspector
        } else if let preset = selectedPreset {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ImageEditorBrushPresetThumbnail(preset: preset)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(preset.title)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(2)
                        Text(L10n.text(
                            preset.isBuiltIn
                                ? "imageEditor.brushPreset.builtInBadge"
                                : "imageEditor.brushPreset.customBadge"
                        ))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    }
                }

                if !preset.isBuiltIn, let index = selectedCustomIndex {
                    customPresetControls(presetID: preset.id, index: index)
                }

                Divider()
                presetSummary(preset)
                Spacer(minLength: 0)
                inspectorActions(preset)
            }
            .padding(16)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: 28))
                Text(L10n.text("imageEditor.brushPreset.managerEmpty"))
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var multipleSelectionInspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color.accentColor)
            Text(L10n.format(
                "imageEditor.brushPreset.multiSelectionTitle",
                selectedPresetIDs.count
            ))
            .font(.system(size: 15, weight: .bold))
            Text(L10n.format(
                "imageEditor.brushPreset.multiSelectionSummary",
                exportableSelectedCustomPresetIDs.count
            ))
            .font(.system(size: 11))
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            Text(L10n.format(
                "imageEditor.brushPreset.multiSelectionFavoriteSummary",
                selectedFavoriteCount,
                selectedVisiblePresetIDs.count
            ))
            .font(.system(size: 11))
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Button {
                    viewModel.setBrushPresetsFavorite(
                        ids: selectedVisiblePresetIDs,
                        isFavorite: true
                    )
                } label: {
                    Label(
                        L10n.text("imageEditor.action.brushPresetFavoriteSelected"),
                        systemImage: "star.fill"
                    )
                }
                .focusable(false)
                .disabled(selectedFavoriteCount == selectedVisiblePresetIDs.count)

                Button {
                    viewModel.setBrushPresetsFavorite(
                        ids: selectedVisiblePresetIDs,
                        isFavorite: false
                    )
                } label: {
                    Label(
                        L10n.text("imageEditor.action.brushPresetUnfavoriteSelected"),
                        systemImage: "star.slash"
                    )
                }
                .focusable(false)
                .disabled(selectedFavoriteCount == 0)
            }
            .accessibilityIdentifier("image-editor-brush-preset-multi-favorite-actions")

            Button(L10n.text("imageEditor.action.brushPresetExportSelected")) {
                viewModel.chooseBrushPresetExportFile(
                    presetIDs: exportableSelectedCustomPresetIDs
                )
            }
            .focusable(false)
            .disabled(exportableSelectedCustomPresetIDs.isEmpty)
        }
        .padding(16)
        .accessibilityIdentifier("image-editor-brush-preset-multi-selection")
    }

    private func presetSectionTitle(_ key: String) -> some View {
        Text(L10n.text(key))
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            .textCase(.uppercase)
            .padding(.horizontal, 4)
            .padding(.top, 5)
    }

    private func presetRow(_ preset: ImageEditorBrushPreset) -> some View {
        reorderablePresetSurface(preset) {
            HStack(spacing: 4) {
                Button {
                    selectPresetFromSurface(preset.id)
                } label: {
                    HStack(spacing: 8) {
                        ImageEditorBrushPresetThumbnail(preset: preset, size: 28)
                        Text(preset.title)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if viewModel.activeBrushPreset?.id == preset.id {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help(L10n.text("imageEditor.brushPreset.multiSelectionHelp"))

                favoriteButton(for: preset)
            }
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .frame(height: 38)
            .background(
                selectedPresetIDs.contains(preset.id)
                    ? Color.accentColor.opacity(0.72)
                    : Color.white.opacity(0.05)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .contextMenu {
            presetContextMenu(preset)
        }
    }

    private func presetTile(_ preset: ImageEditorBrushPreset) -> some View {
        reorderablePresetSurface(preset) {
            ZStack(alignment: .topTrailing) {
                Button {
                    selectPresetFromSurface(preset.id)
                } label: {
                    VStack(spacing: 6) {
                        ImageEditorBrushPresetThumbnail(
                            preset: preset,
                            size: gridDensity.thumbnailSize
                        )
                        HStack(spacing: 4) {
                            Text(preset.title)
                                .lineLimit(1)
                            if viewModel.activeBrushPreset?.id == preset.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help(L10n.text("imageEditor.brushPreset.multiSelectionHelp"))

                favoriteButton(for: preset)
                    .padding(5)
            }
            .font(.system(size: 10, weight: .semibold))
            .padding(6)
            .frame(minHeight: gridDensity.minimumTileHeight)
            .background(
                selectedPresetIDs.contains(preset.id)
                    ? Color.accentColor.opacity(0.72)
                    : Color.white.opacity(0.05)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .contextMenu {
            presetContextMenu(preset)
        }
    }

    @ViewBuilder
    private func reorderablePresetSurface<Content: View>(
        _ preset: ImageEditorBrushPreset,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let surface = content()
            .overlay {
                if reorderDropTargetID == preset.id {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }

        if ImageEditorBrushPresetReorderPolicy.canReorder(
            preset,
            collection: collection,
            sortOrder: sortOrder
        ) {
            surface
                .draggable(preset.id) {
                    Label(preset.title, systemImage: "paintbrush.pointed")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(8)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .dropDestination(for: String.self) { draggedIDs, _ in
                    guard let move = ImageEditorBrushPresetReorderPolicy.resolvedMove(
                        draggedIDs: draggedIDs,
                        onto: preset.id,
                        customPresets: viewModel.customBrushPresets
                    ),
                    viewModel.moveCustomBrushPreset(
                        id: move.sourceID,
                        toIndex: move.destinationIndex
                    ) else { return false }
                    selectOnly(move.sourceID)
                    reorderDropTargetID = nil
                    return true
                } isTargeted: { isTargeted in
                    if isTargeted {
                        reorderDropTargetID = preset.id
                    } else if reorderDropTargetID == preset.id {
                        reorderDropTargetID = nil
                    }
                }
                .accessibilityIdentifier("image-editor-brush-preset-reorder-\(preset.id)")
                .help(L10n.text("imageEditor.brushPreset.reorderHelp"))
        } else {
            surface
        }
    }

    private func favoriteButton(for preset: ImageEditorBrushPreset) -> some View {
        Button {
            viewModel.setBrushPresetFavorite(
                id: preset.id,
                isFavorite: !viewModel.isFavoriteBrushPreset(id: preset.id)
            )
        } label: {
            Image(systemName: viewModel.isFavoriteBrushPreset(id: preset.id) ? "star.fill" : "star")
                .foregroundStyle(
                    viewModel.isFavoriteBrushPreset(id: preset.id)
                        ? Color.yellow.opacity(0.9)
                        : Color(nsColor: ImageEditorTheme.mutedText)
                )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(L10n.text(
            viewModel.isFavoriteBrushPreset(id: preset.id)
                ? "imageEditor.action.brushPresetUnfavorite"
                : "imageEditor.action.brushPresetFavorite"
        ))
        .accessibilityIdentifier("image-editor-brush-preset-favorite-\(preset.id)")
    }

    @ViewBuilder
    private func presetContextMenu(_ preset: ImageEditorBrushPreset) -> some View {
        let policy = ImageEditorBrushPresetContextPolicy(
            preset: preset,
            customPresets: viewModel.customBrushPresets
        )

        Button(L10n.text("imageEditor.action.brushPresetApply")) {
            selectOnly(preset.id)
            viewModel.applyBrushPreset(preset)
        }
        Button(L10n.text(
            viewModel.isFavoriteBrushPreset(id: preset.id)
                ? "imageEditor.action.brushPresetUnfavorite"
                : "imageEditor.action.brushPresetFavorite"
        )) {
            viewModel.setBrushPresetFavorite(
                id: preset.id,
                isFavorite: !viewModel.isFavoriteBrushPreset(id: preset.id)
            )
        }

        if policy.isCustom {
            Divider()
            Button(L10n.text("imageEditor.action.brushPresetRename")) {
                beginRenaming(preset)
            }
            Button(L10n.text("imageEditor.action.brushPresetUpdate")) {
                selectPresetForManagement(preset)
                viewModel.updateCustomBrushPresetFromCurrentSettings(id: preset.id)
            }
            Button(L10n.text("imageEditor.action.brushPresetDuplicate")) {
                if let copy = viewModel.duplicateCustomBrushPreset(id: preset.id) {
                    selectPresetForManagement(copy)
                }
            }

            Divider()
            Button(L10n.text("imageEditor.action.brushPresetMoveUp")) {
                movePresetFromContextMenu(preset, destinationIndex: policy.moveUpDestinationIndex)
            }
            .disabled(!policy.canMoveUp)
            Button(L10n.text("imageEditor.action.brushPresetMoveDown")) {
                movePresetFromContextMenu(preset, destinationIndex: policy.moveDownDestinationIndex)
            }
            .disabled(!policy.canMoveDown)

            Divider()
            Button(L10n.text("imageEditor.action.brushPresetExport")) {
                viewModel.chooseBrushPresetExportFile(presetIDs: [preset.id])
            }
            Button(
                L10n.text("imageEditor.action.brushPresetDelete"),
                role: .destructive
            ) {
                viewModel.deleteBrushPreset(preset)
            }
        }
    }

    private func customPresetControls(presetID: String, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("imageEditor.brushPreset.name"))
                .font(.system(size: 11, weight: .semibold))
            HStack(spacing: 8) {
                TextField(
                    L10n.text("imageEditor.brushPreset.namePlaceholder"),
                    text: $nameDraft
                )
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .onSubmit {
                    renameSelectedPreset()
                }
                Button(L10n.text("imageEditor.action.brushPresetRename")) {
                    renameSelectedPreset()
                }
                .focusable(false)
                .disabled(ImageEditorBrushPreset.normalizedCustomName(nameDraft) == nil)
            }

            HStack(spacing: 8) {
                managerButton("imageEditor.action.brushPresetMoveUp", symbol: "arrow.up") {
                    viewModel.moveCustomBrushPreset(id: presetID, toIndex: index - 1)
                }
                .disabled(index == 0)
                managerButton("imageEditor.action.brushPresetMoveDown", symbol: "arrow.down") {
                    viewModel.moveCustomBrushPreset(id: presetID, toIndex: index + 1)
                }
                .disabled(index == viewModel.customBrushPresets.count - 1)
                managerButton("imageEditor.action.brushPresetUpdate", symbol: "square.and.arrow.down") {
                    viewModel.updateCustomBrushPresetFromCurrentSettings(id: presetID)
                }
            }
        }
    }

    private func presetSummary(_ preset: ImageEditorBrushPreset) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L10n.text("imageEditor.brushPreset.summary"))
                .font(.system(size: 11, weight: .semibold))
            Text(L10n.format(
                "imageEditor.brushPreset.summaryPrimary",
                Int(preset.size.rounded()),
                Int((preset.hardness * 100).rounded()),
                Int(preset.flow.rounded()),
                Int(preset.spacing.rounded())
            ))
            Text(L10n.format(
                "imageEditor.brushPreset.summaryTip",
                Int(preset.tipRoundness.rounded()),
                Int(preset.tipAngleDegrees.rounded()),
                Int(preset.smoothing.rounded())
            ))
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
        }
        .font(.system(size: 11).monospacedDigit())
    }

    private func inspectorActions(_ preset: ImageEditorBrushPreset) -> some View {
        HStack(spacing: 8) {
            Button {
                viewModel.setBrushPresetFavorite(
                    id: preset.id,
                    isFavorite: !viewModel.isFavoriteBrushPreset(id: preset.id)
                )
            } label: {
                Label(
                    L10n.text(
                        viewModel.isFavoriteBrushPreset(id: preset.id)
                            ? "imageEditor.action.brushPresetUnfavorite"
                            : "imageEditor.action.brushPresetFavorite"
                    ),
                    systemImage: viewModel.isFavoriteBrushPreset(id: preset.id)
                        ? "star.fill"
                        : "star"
                )
            }
            .focusable(false)

            Button(L10n.text("imageEditor.action.brushPresetApply")) {
                viewModel.applyBrushPreset(preset)
            }
            .focusable(false)

            Spacer()
            if !preset.isBuiltIn {
                Button(L10n.text("imageEditor.action.brushPresetExport")) {
                    viewModel.chooseBrushPresetExportFile(presetIDs: [preset.id])
                }
                .focusable(false)
                Button(L10n.text("imageEditor.action.brushPresetDuplicate")) {
                    if let copy = viewModel.duplicateCustomBrushPreset(id: preset.id) {
                        selectOnly(copy.id)
                    }
                }
                .focusable(false)
                Button(L10n.text("imageEditor.action.brushPresetDelete"), role: .destructive) {
                    viewModel.deleteBrushPreset(preset)
                }
                .focusable(false)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button(L10n.text("imageEditor.action.brushPresetCreate")) {
                if let preset = viewModel.createBrushPresetFromCurrentSettings() {
                    selectOnly(preset.id)
                }
            }
            .focusable(false)

            Menu(L10n.text("imageEditor.action.brushPresetLibraryMenu")) {
                Button(L10n.text("imageEditor.action.brushPresetImport")) {
                    viewModel.chooseBrushPresetImportFile()
                }
                Button(L10n.text("imageEditor.action.brushPresetReplaceLibrary")) {
                    viewModel.chooseBrushPresetReplacementFile()
                }
                Divider()
                Button(
                    L10n.text("imageEditor.action.brushPresetResetLibrary"),
                    role: .destructive
                ) {
                    viewModel.confirmBrushPresetLibraryReset()
                }
                .disabled(!viewModel.canResetCustomBrushPresetLibrary)
            }
            .focusable(false)

            Menu(L10n.text("imageEditor.action.brushPresetExportMenu")) {
                Button(L10n.text("imageEditor.action.brushPresetExportSelected")) {
                    viewModel.chooseBrushPresetExportFile(
                        presetIDs: exportableSelectedCustomPresetIDs
                    )
                }
                .disabled(exportableSelectedCustomPresetIDs.isEmpty)

                Button(L10n.text("imageEditor.action.brushPresetExportVisible")) {
                    viewModel.chooseBrushPresetExportFile(
                        presetIDs: exportableVisibleCustomPresetIDs
                    )
                }
                .disabled(exportableVisibleCustomPresetIDs.isEmpty)

                Button(L10n.text("imageEditor.action.brushPresetExportAll")) {
                    viewModel.chooseBrushPresetExportFile()
                }
                .disabled(viewModel.customBrushPresets.isEmpty)
            }
            .focusable(false)

            Spacer()
            Button(L10n.text("action.done")) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private var emptyListMessageKey: String {
        let hasSearch = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasSearch { return "imageEditor.brushPreset.noResults" }
        switch collection {
        case .favorites:
            return "imageEditor.brushPreset.noFavorites"
        case .recent:
            return "imageEditor.brushPreset.noRecent"
        case .all:
            return scope == .custom && viewModel.customBrushPresets.isEmpty
                ? "imageEditor.brushPreset.noCustom"
                : "imageEditor.brushPreset.noResults"
        }
    }

    private var selectionState: ImageEditorBrushPresetSelectionState {
        ImageEditorBrushPresetSelectionState(
            selectedIDs: selectedPresetIDs,
            primaryID: selectedPresetID,
            anchorID: selectionAnchorID
        )
    }

    private func selectPresetFromSurface(_ presetID: String) {
        let modifierFlags = NSEvent.modifierFlags
        let gesture = ImageEditorBrushPresetSelectionGesture.resolved(
            isCommandPressed: modifierFlags.contains(.command),
            isShiftPressed: modifierFlags.contains(.shift)
        )
        applySelectionState(selectionState.selecting(
            presetID,
            gesture: gesture,
            orderedIDs: filteredPresets.map(\.id)
        ))
    }

    private func selectOnly(_ presetID: String?) {
        guard let presetID else {
            applySelectionState(ImageEditorBrushPresetSelectionState())
            return
        }
        applySelectionState(ImageEditorBrushPresetSelectionState(
            selectedIDs: [presetID],
            primaryID: presetID,
            anchorID: presetID
        ))
    }

    private func applySelectionState(_ state: ImageEditorBrushPresetSelectionState) {
        selectedPresetIDs = state.selectedIDs
        selectedPresetID = state.primaryID
        selectionAnchorID = state.anchorID
    }

    private func selectAllVisiblePresets() {
        applySelectionState(
            selectionState.selectingAll(orderedIDs: filteredPresets.map(\.id))
        )
    }

    private func deselectAllPresets() {
        applySelectionState(selectionState.deselectingAll())
    }

    private func invertVisiblePresetSelection() {
        applySelectionState(
            selectionState.inverting(orderedIDs: filteredPresets.map(\.id))
        )
    }

    private func selectInitialPreset() {
        selectOnly(query.repairedSelectionID(
            viewModel.selectedBrushPreset?.id ?? viewModel.activeBrushPreset?.id,
            in: viewModel.brushPresets
        ))
        syncNameDraft()
    }

    private func repairSelection() {
        applySelectionState(
            selectionState.repaired(visibleIDs: filteredPresets.map(\.id))
        )
    }

    private func syncNameDraft() {
        nameDraft = selectedPreset?.title ?? ""
    }

    private func selectPresetForManagement(_ preset: ImageEditorBrushPreset) {
        selectOnly(preset.id)
        nameDraft = preset.title
    }

    private func beginRenaming(_ preset: ImageEditorBrushPreset) {
        selectPresetForManagement(preset)
        DispatchQueue.main.async {
            isNameFieldFocused = true
        }
    }

    private func movePresetFromContextMenu(
        _ preset: ImageEditorBrushPreset,
        destinationIndex: Int?
    ) {
        guard let destinationIndex,
              viewModel.moveCustomBrushPreset(
                id: preset.id,
                toIndex: destinationIndex
              )
        else { return }
        selectPresetForManagement(preset)
    }

    private func renameSelectedPreset() {
        guard let selectedPresetID,
              viewModel.renameCustomBrushPreset(id: selectedPresetID, to: nameDraft)
        else { return }
        syncNameDraft()
    }

    private func managerButton(
        _ key: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(L10n.text(key), systemImage: symbol)
        }
        .focusable(false)
    }
}

private struct ImageEditorBrushPresetThumbnail: View {
    let preset: ImageEditorBrushPreset
    var size: CGFloat = 82

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.26))
            Ellipse()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: .white, location: min(0.98, preset.hardness)),
                            .init(color: .white.opacity(0.12), location: 1)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.38
                    )
                )
                .frame(
                    width: size * 0.72,
                    height: max(6, size * 0.72 * preset.tipRoundness / 100)
                )
                .rotationEffect(.degrees(Double(preset.tipAngleDegrees)))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
