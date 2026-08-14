import SwiftUI

struct ImageEditorHotspotDraft: Equatable {
    var name: String
    var url: String
    var x: String
    var y: String
    var width: String
    var height: String

    init(_ hotspot: ImageEditorHotspot) {
        name = hotspot.name
        url = hotspot.url
        x = Self.number(hotspot.frame.minX)
        y = Self.number(hotspot.frame.minY)
        width = Self.number(hotspot.frame.width)
        height = Self.number(hotspot.frame.height)
    }

    private static func number(_ value: CGFloat) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.2f", value)
    }
}

struct ImageEditorHotspotPanel: View {
    @ObservedObject var viewModel: ImageEditorViewModel
    let showsTitle: Bool
    @State private var drafts: [UUID: ImageEditorHotspotDraft] = [:]

    init(viewModel: ImageEditorViewModel, showsTitle: Bool = true) {
        self.viewModel = viewModel
        self.showsTitle = showsTitle
    }

    var body: some View {
        EditorPanel(title: L10n.text("imageEditor.panel.hotspots"), showsTitle: showsTitle) {
            if viewModel.availableHotspots.isEmpty {
                Text(L10n.text("imageEditor.hotspots.empty"))
                    .font(.system(size: 12))
                    .foregroundColor(Color(nsColor: ImageEditorTheme.mutedText))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("imageEditor.hotspots.hint"))
                        .font(.system(size: 11))
                        .foregroundColor(Color(nsColor: ImageEditorTheme.mutedText))

                    ForEach(viewModel.availableHotspots) { hotspot in
                        ImageEditorHotspotPanelRow(
                            hotspot: hotspot,
                            draft: draftBinding(for: hotspot),
                            isSelected: viewModel.selectedHotspotID == hotspot.id,
                            onSelect: { viewModel.selectedHotspotID = hotspot.id },
                            onSave: { save($0, for: hotspot) },
                            onDelete: { delete(hotspot) }
                        )
                    }
                }
            }
        }
        .onAppear(perform: syncDrafts)
        .onChange(of: viewModel.document.hotspots) { _ in
            syncDrafts()
        }
    }

    private func draftBinding(for hotspot: ImageEditorHotspot) -> Binding<ImageEditorHotspotDraft> {
        Binding(
            get: { drafts[hotspot.id] ?? ImageEditorHotspotDraft(hotspot) },
            set: { drafts[hotspot.id] = $0 }
        )
    }

    private func save(_ draft: ImageEditorHotspotDraft, for hotspot: ImageEditorHotspot) {
        guard let x = Double(draft.x),
              let y = Double(draft.y),
              let width = Double(draft.width),
              let height = Double(draft.height)
        else {
            viewModel.statusText = L10n.text("imageEditor.status.hotspotInvalidFrame")
            return
        }
        _ = viewModel.updateHotspot(
            id: hotspot.id,
            name: draft.name,
            url: draft.url,
            frame: CGRect(x: x, y: y, width: width, height: height)
        )
        syncDrafts()
    }

    private func delete(_ hotspot: ImageEditorHotspot) {
        _ = viewModel.deleteHotspot(id: hotspot.id)
        drafts.removeValue(forKey: hotspot.id)
    }

    private func syncDrafts() {
        let currentIDs = Set(viewModel.availableHotspots.map(\.id))
        var next = drafts.filter { currentIDs.contains($0.key) }
        for hotspot in viewModel.availableHotspots where next[hotspot.id] == nil {
            next[hotspot.id] = ImageEditorHotspotDraft(hotspot)
        }
        drafts = next
        if let selected = viewModel.selectedHotspotID,
           currentIDs.contains(selected) == false {
            viewModel.selectedHotspotID = viewModel.availableHotspots.first?.id
        }
    }
}

private struct ImageEditorHotspotPanelRow: View {
    let hotspot: ImageEditorHotspot
    @Binding var draft: ImageEditorHotspotDraft
    let isSelected: Bool
    let onSelect: () -> Void
    let onSave: (ImageEditorHotspotDraft) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "scope" : "rectangle.dashed")
                    .foregroundColor(Color.orange)
                Text(draft.name.isEmpty ? hotspot.name : draft.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(nsColor: ImageEditorTheme.text))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .help(L10n.text("imageEditor.hotspots.delete"))
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)

            TextField(L10n.text("imageEditor.hotspots.name"), text: $draft.name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { onSave(draft) }
            TextField(L10n.text("imageEditor.hotspots.url"), text: $draft.url)
                .textFieldStyle(.roundedBorder)
                .onSubmit { onSave(draft) }

            HStack(spacing: 4) {
                coordinateField("imageEditor.hotspots.x", text: $draft.x)
                coordinateField("imageEditor.hotspots.y", text: $draft.y)
                coordinateField("imageEditor.hotspots.width", text: $draft.width)
                coordinateField("imageEditor.hotspots.height", text: $draft.height)
            }

            Button(L10n.text("imageEditor.hotspots.save")) {
                onSave(draft)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .focusable(false)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: isSelected ? ImageEditorTheme.selected.withAlphaComponent(0.25) : ImageEditorTheme.chrome))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.orange.opacity(isSelected ? 0.7 : 0.18), lineWidth: 1)
        )
    }

    private func coordinateField(_ key: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.text(key))
                .font(.system(size: 9))
                .foregroundColor(Color(nsColor: ImageEditorTheme.mutedText))
            TextField("0", text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10))
                .onSubmit { onSave(draft) }
        }
        .frame(minWidth: 48)
    }
}

struct ImageEditorSliceDraft: Equatable {
    var name: String
    var x: String
    var y: String
    var width: String
    var height: String
    var exportPresetSuffixes: [String]

    init(_ slice: ImageEditorSlice) {
        name = slice.name
        x = Self.number(slice.frame.minX)
        y = Self.number(slice.frame.minY)
        width = Self.number(slice.frame.width)
        height = Self.number(slice.frame.height)
        exportPresetSuffixes = (slice.exportPresets ?? []).map(\.suffix)
    }

    private static func number(_ value: CGFloat) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.2f", value)
    }
}

struct ImageEditorSlicePanel: View {
    @ObservedObject var viewModel: ImageEditorViewModel
    let showsTitle: Bool
    @State private var drafts: [UUID: ImageEditorSliceDraft] = [:]

    init(viewModel: ImageEditorViewModel, showsTitle: Bool = true) {
        self.viewModel = viewModel
        self.showsTitle = showsTitle
    }

    var body: some View {
        EditorPanel(title: L10n.text("imageEditor.panel.slices"), showsTitle: showsTitle) {
            if viewModel.availableSlices.isEmpty {
                Text(L10n.text("imageEditor.slices.empty"))
                    .font(.system(size: 12))
                    .foregroundColor(Color(nsColor: ImageEditorTheme.mutedText))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("imageEditor.slices.hint"))
                        .font(.system(size: 11))
                        .foregroundColor(Color(nsColor: ImageEditorTheme.mutedText))

                    ForEach(viewModel.availableSlices) { slice in
                        ImageEditorSlicePanelRow(
                            slice: slice,
                            draft: draftBinding(for: slice),
                            isSelected: viewModel.exportSettings.sliceID == slice.id,
                            onSelect: { select(slice) },
                            onSave: { save($0, for: slice) },
                            onAddExportPreset: { addExportPreset(to: slice) },
                            onDeleteExportPreset: { deleteExportPreset(at: $0, from: slice) },
                            onMoveExportPreset: { moveExportPreset(at: $0, in: slice, direction: $1) },
                            onUpdateExportPresetSuffix: {
                                updateExportPresetSuffix(at: $0, suffix: $1, in: slice)
                            },
                            onDelete: { delete(slice) }
                        )
                    }
                }
            }
        }
        .onAppear(perform: syncDrafts)
        .onChange(of: viewModel.document.slices) { _ in
            syncDrafts()
        }
    }

    private func draftBinding(for slice: ImageEditorSlice) -> Binding<ImageEditorSliceDraft> {
        Binding(
            get: { drafts[slice.id] ?? ImageEditorSliceDraft(slice) },
            set: { drafts[slice.id] = $0 }
        )
    }

    private func select(_ slice: ImageEditorSlice) {
        _ = viewModel.selectSlice(id: slice.id)
    }

    private func save(_ draft: ImageEditorSliceDraft, for slice: ImageEditorSlice) {
        guard let x = Double(draft.x),
              let y = Double(draft.y),
              let width = Double(draft.width),
              let height = Double(draft.height)
        else {
            viewModel.statusText = L10n.text("imageEditor.status.sliceInvalidFrame")
            return
        }
        _ = viewModel.updateSlice(
            id: slice.id,
            name: draft.name,
            frame: CGRect(x: x, y: y, width: width, height: height)
        )
        syncDrafts()
    }

    private func delete(_ slice: ImageEditorSlice) {
        _ = viewModel.deleteSlice(id: slice.id)
        drafts.removeValue(forKey: slice.id)
    }

    private func addExportPreset(to slice: ImageEditorSlice) {
        _ = viewModel.addCurrentExportPreset(toSlice: slice.id)
    }

    private func deleteExportPreset(at index: Int, from slice: ImageEditorSlice) {
        _ = viewModel.removeSliceExportPreset(fromSlice: slice.id, at: index)
    }

    private func moveExportPreset(
        at index: Int,
        in slice: ImageEditorSlice,
        direction: ImageEditorSliceExportPresetMoveDirection
    ) {
        _ = viewModel.moveSliceExportPreset(
            inSlice: slice.id,
            from: index,
            direction: direction
        )
    }

    private func updateExportPresetSuffix(at index: Int, suffix: String, in slice: ImageEditorSlice) {
        _ = viewModel.updateSliceExportPresetSuffix(
            inSlice: slice.id,
            at: index,
            suffix: suffix
        )
        syncDrafts()
    }

    private func syncDrafts() {
        let currentIDs = Set(viewModel.availableSlices.map(\.id))
        var next = drafts.filter { currentIDs.contains($0.key) }
        for slice in viewModel.availableSlices {
            if var existing = next[slice.id] {
                existing.exportPresetSuffixes = (slice.exportPresets ?? []).map(\.suffix)
                next[slice.id] = existing
            } else {
                next[slice.id] = ImageEditorSliceDraft(slice)
            }
        }
        drafts = next
        if let selected = viewModel.exportSettings.sliceID,
           currentIDs.contains(selected) == false {
            viewModel.exportSettings.sliceID = viewModel.availableSlices.first?.id
        }
    }
}

private struct ImageEditorSlicePanelRow: View {
    let slice: ImageEditorSlice
    @Binding var draft: ImageEditorSliceDraft
    let isSelected: Bool
    let onSelect: () -> Void
    let onSave: (ImageEditorSliceDraft) -> Void
    let onAddExportPreset: () -> Void
    let onDeleteExportPreset: (Int) -> Void
    let onMoveExportPreset: (Int, ImageEditorSliceExportPresetMoveDirection) -> Void
    let onUpdateExportPresetSuffix: (Int, String) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "scope" : "rectangle.dashed")
                    .foregroundColor(Color.cyan)
                Text(draft.name.isEmpty ? slice.name : draft.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(nsColor: ImageEditorTheme.text))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .help(L10n.text("imageEditor.slices.delete"))
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)

            if let presets = slice.exportPresets, !presets.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(presets.indices, id: \.self) { index in
                        HStack(spacing: 4) {
                            Text(exportPresetSummary(presets[index]))
                                .font(.system(size: 10))
                                .foregroundColor(Color(nsColor: ImageEditorTheme.mutedText))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Button {
                                onMoveExportPreset(index, .up)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                            .focusable(false)
                            .disabled(index == presets.startIndex)
                            .help(L10n.text("imageEditor.slices.exportPreset.moveUp"))
                            Button {
                                onMoveExportPreset(index, .down)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.borderless)
                            .focusable(false)
                            .disabled(index == presets.index(before: presets.endIndex))
                            .help(L10n.text("imageEditor.slices.exportPreset.moveDown"))
                            Button {
                                onDeleteExportPreset(index)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .focusable(false)
                            .help(L10n.text("imageEditor.slices.exportPreset.remove"))
                        }
                        if isSelected {
                            HStack(spacing: 4) {
                                TextField(
                                    L10n.text("imageEditor.slices.exportPreset.suffix"),
                                    text: exportPresetSuffixBinding(
                                        at: index,
                                        fallback: presets[index].suffix
                                    )
                                )
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 10))
                                .onSubmit {
                                    onUpdateExportPresetSuffix(
                                        index,
                                        exportPresetSuffix(
                                            at: index,
                                            fallback: presets[index].suffix
                                        )
                                    )
                                }
                                Button {
                                    onUpdateExportPresetSuffix(
                                        index,
                                        exportPresetSuffix(
                                            at: index,
                                            fallback: presets[index].suffix
                                        )
                                    )
                                } label: {
                                    Image(systemName: "checkmark")
                                }
                                .buttonStyle(.borderless)
                                .focusable(false)
                                .help(L10n.text("imageEditor.slices.exportPreset.applySuffix"))
                            }
                        }
                    }
                }
            }

            if isSelected {
                Button(L10n.text("imageEditor.slices.exportPreset.addCurrent")) {
                    onAddExportPreset()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .focusable(false)
            }

            TextField(L10n.text("imageEditor.slices.name"), text: $draft.name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { onSave(draft) }

            HStack(spacing: 4) {
                coordinateField("imageEditor.slices.x", text: $draft.x)
                coordinateField("imageEditor.slices.y", text: $draft.y)
                coordinateField("imageEditor.slices.width", text: $draft.width)
                coordinateField("imageEditor.slices.height", text: $draft.height)
            }

            Button(L10n.text("imageEditor.slices.save")) {
                onSave(draft)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .focusable(false)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: isSelected ? ImageEditorTheme.selected.withAlphaComponent(0.25) : ImageEditorTheme.chrome))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.cyan.opacity(isSelected ? 0.7 : 0.18), lineWidth: 1)
        )
    }

    private func exportPresetSummary(_ preset: ImageEditorSliceExportPreset) -> String {
        let value = ImageEditorExportScaleFormatter.string(from: preset.value)
        let constraint: String
        switch preset.constraint {
        case .scale:
            constraint = L10n.format("imageEditor.slices.exportPreset.scale", value)
        case .width:
            constraint = L10n.format("imageEditor.slices.exportPreset.width", value)
        case .height:
            constraint = L10n.format("imageEditor.slices.exportPreset.height", value)
        }
        if preset.suffix.isEmpty {
            return "\(preset.format.title) · \(constraint)"
        }
        return "\(preset.format.title) · \(constraint) · \(preset.suffix)"
    }

    private func exportPresetSuffixBinding(at index: Int, fallback: String) -> Binding<String> {
        Binding(
            get: {
                draft.exportPresetSuffixes.indices.contains(index)
                    ? draft.exportPresetSuffixes[index]
                    : fallback
            },
            set: { value in
                guard draft.exportPresetSuffixes.indices.contains(index) else { return }
                draft.exportPresetSuffixes[index] = value
            }
        )
    }

    private func exportPresetSuffix(at index: Int, fallback: String) -> String {
        draft.exportPresetSuffixes.indices.contains(index)
            ? draft.exportPresetSuffixes[index]
            : fallback
    }

    private func coordinateField(_ key: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.text(key))
                .font(.system(size: 9))
                .foregroundColor(Color(nsColor: ImageEditorTheme.mutedText))
            TextField("0", text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10))
                .onSubmit { onSave(draft) }
        }
        .frame(minWidth: 48)
    }
}
