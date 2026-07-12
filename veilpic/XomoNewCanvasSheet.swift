import SwiftUI

struct XomoNewCanvasSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ImageEditorViewModel
    @State private var draft = XomoCanvasDraft()

    private let columns = [
        GridItem(.flexible(minimum: 150), spacing: 10),
        GridItem(.flexible(minimum: 150), spacing: 10),
        GridItem(.flexible(minimum: 150), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.text("xomo.newCanvas.title"))
                    .font(.title2.weight(.semibold))
                Text(L10n.text("xomo.newCanvas.subtitle"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(XomoCanvasPresetCategory.allCases) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.title)
                                .font(.headline)
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(XomoCanvasPreset.allCases.filter { $0.category == category }) { preset in
                                    presetButton(preset)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Divider()

            HStack(spacing: 12) {
                dimensionField("xomo.newCanvas.width", value: $draft.width)
                dimensionField("xomo.newCanvas.height", value: $draft.height)
                Picker(L10n.text("xomo.newCanvas.background"), selection: $draft.background) {
                    ForEach(XomoCanvasBackground.allCases) { background in
                        Text(background.title).tag(background)
                    }
                }
                .frame(width: 150)
                Stepper(value: $draft.exportScale, in: 1...3) {
                    Text(L10n.format("xomo.newCanvas.exportScale", draft.clampedExportScale))
                }
                .frame(width: 118)
            }

            HStack {
                Text(L10n.format("xomo.newCanvas.gridSummary", Int(XomoCanvasDraft.defaultGridSpacing), Int(draft.selectedPreset.suggestedMargin)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L10n.text("imageEditor.action.cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(L10n.text("xomo.newCanvas.create")) {
                    viewModel.createCanvas(from: draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("xomo-new-canvas-create")
            }
        }
        .padding(22)
        .frame(width: 650, height: 680)
        .accessibilityIdentifier("xomo-new-canvas-sheet")
    }

    private func dimensionField(_ titleKey: String, value: Binding<Double>) -> some View {
        HStack(spacing: 6) {
            Text(L10n.text(titleKey))
            TextField("", value: value, format: .number.precision(.fractionLength(0)))
                .frame(width: 82)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func presetButton(_ preset: XomoCanvasPreset) -> some View {
        Button {
            draft.apply(preset)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(Int(preset.logicalSize.width)) × \(Int(preset.logicalSize.height))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(L10n.format("xomo.newCanvas.presetScale", preset.defaultExportScale))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(background(for: preset))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(borderColor(for: preset), lineWidth: preset == draft.selectedPreset ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("xomo-canvas-preset-\(preset.rawValue)")
    }

    private func background(for preset: XomoCanvasPreset) -> Color {
        preset == draft.selectedPreset
            ? Color.accentColor.opacity(0.16)
            : Color.secondary.opacity(0.08)
    }

    private func borderColor(for preset: XomoCanvasPreset) -> Color {
        preset == draft.selectedPreset ? .accentColor : Color.secondary.opacity(0.24)
    }
}
