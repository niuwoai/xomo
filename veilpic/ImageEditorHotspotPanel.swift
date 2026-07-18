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
