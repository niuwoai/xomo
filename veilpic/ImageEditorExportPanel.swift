//
//  ImageEditorExportPanel.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import SwiftUI

enum ImageEditorExportScaleFormatter {
    static func string(from scale: Double) -> String {
        let rounded = (scale * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        if (rounded * 10).rounded() == rounded * 10 {
            return String(format: "%.1f", rounded)
        }
        return String(format: "%.2f", rounded)
    }
}

struct ImageEditorExportPanel: View {
    @ObservedObject var viewModel: ImageEditorViewModel

    private enum Layout {
        static let panelWidth: CGFloat = 532
        static let labelWidth: CGFloat = 72
        static let rowSpacing: CGFloat = 10
        static let rowHeight: CGFloat = 26
        static let menuWidth: CGFloat = 190
        static let namingMenuWidth: CGFloat = 240
        static let scopePickerMinimumWidth: CGFloat = 392
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(L10n.text("imageEditor.export.title"), systemImage: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button {
                    viewModel.isExportSheetPresented = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help(L10n.text("imageEditor.action.cancel"))
            }

            VStack(alignment: .leading, spacing: 10) {
                exportFormRow(L10n.text("imageEditor.export.format")) {
                    Picker("", selection: formatBinding) {
                        ForEach(ImageEditorExportFormat.allCases) { format in
                            Text(format.title)
                                .tag(format)
                                .disabled(format == .svg && !viewModel.canExportSVG)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: Layout.menuWidth, alignment: .leading)
                    .accessibilityLabel(L10n.text("imageEditor.export.format"))
                }

                exportFormRow(L10n.text("imageEditor.export.scope")) {
                    Picker("", selection: scopeBinding) {
                        ForEach(ImageEditorExportScope.allCases) { scope in
                            Text(scope.title)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .tag(scope)
                                .disabled(isScopeDisabled(scope))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .frame(minWidth: Layout.scopePickerMinimumWidth, alignment: .leading)
                    .accessibilityLabel(L10n.text("imageEditor.export.scope"))
                }

                if viewModel.exportSettings.scope == .slice {
                    exportFormRow(L10n.text("imageEditor.export.slice")) {
                        Picker("", selection: sliceBinding) {
                            ForEach(viewModel.availableSlices) { slice in
                                Text(slice.name).tag(Optional(slice.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: Layout.namingMenuWidth, alignment: .leading)
                        .accessibilityLabel(L10n.text("imageEditor.export.slice"))
                    }
                }

                exportFormRow(L10n.text("imageEditor.export.namingRule")) {
                    Picker("", selection: namingRuleBinding) {
                        ForEach(ImageEditorExportNamingRule.allCases) { rule in
                            Text(rule.title).tag(rule)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: Layout.namingMenuWidth, alignment: .leading)
                    .accessibilityLabel(L10n.text("imageEditor.export.namingRule"))
                }

                if viewModel.exportSettings.usesScale {
                    exportFormRow(
                        L10n.format(
                            "imageEditor.export.scaleValue",
                            ImageEditorExportScaleFormatter.string(from: viewModel.exportSettings.scale)
                        )
                    ) {
                        Stepper(
                            "",
                            value: scaleBinding,
                            in: 0.25...4,
                            step: 0.25
                        )
                        .labelsHidden()
                        .accessibilityLabel(
                            L10n.format(
                                "imageEditor.export.scaleValue",
                                ImageEditorExportScaleFormatter.string(from: viewModel.exportSettings.scale)
                            )
                        )
                    }

                    exportFormRow(L10n.text("imageEditor.export.batchScales")) {
                        HStack(spacing: 10) {
                            ForEach(ImageEditorExportSettings.batchScalePresets, id: \.self) { scale in
                                Toggle(
                                    L10n.format("imageEditor.export.batchScaleValue", scale),
                                    isOn: batchScaleBinding(for: scale)
                                )
                                .toggleStyle(.checkbox)
                                .font(.system(size: 12))
                            }
                        }
                    }
                }

                if viewModel.exportSettings.usesQuality {
                    exportFormRow(L10n.text("imageEditor.export.quality")) {
                        HStack {
                            Slider(value: qualityBinding, in: 0.1...1, step: 0.05)
                            Text(L10n.format("imageEditor.export.qualityValue", Int((viewModel.exportSettings.quality * 100).rounded())))
                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }

                exportFormRow(L10n.text("imageEditor.export.outputSize")) {
                    HStack {
                        Spacer()
                        Text(viewModel.exportSizeText)
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                    }
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                }
            }

            HStack {
                Spacer()
                Button(L10n.text("imageEditor.action.cancel")) {
                    viewModel.isExportSheetPresented = false
                }
                .buttonStyle(.bordered)

                Button(L10n.text("imageEditor.export.saveAs")) {
                    viewModel.runExport()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: Layout.panelWidth)
        .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
        .environment(\.colorScheme, .dark)
        .background(Color(nsColor: ImageEditorTheme.panel))
    }

    private func exportFormRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: Layout.rowSpacing) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .frame(width: Layout.labelWidth, alignment: .leading)
                .layoutPriority(2)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
        }
        .frame(minHeight: Layout.rowHeight)
    }

    private var formatBinding: Binding<ImageEditorExportFormat> {
        Binding(
            get: { viewModel.exportSettings.format },
            set: { format in
                viewModel.exportSettings.format = format
                if format == .svg {
                    viewModel.exportSettings.scope = .composited
                    viewModel.exportSettings.scale = 1
                }
            }
        )
    }

    private var scopeBinding: Binding<ImageEditorExportScope> {
        Binding(
            get: { viewModel.exportSettings.scope },
            set: { scope in
                viewModel.exportSettings.scope = scope
                if scope == .slice,
                   viewModel.exportSettings.sliceID == nil {
                    viewModel.exportSettings.sliceID = viewModel.availableSlices.first?.id
                }
            }
        )
    }

    private var namingRuleBinding: Binding<ImageEditorExportNamingRule> {
        Binding(
            get: { viewModel.exportSettings.namingRule },
            set: { viewModel.exportSettings.namingRule = $0 }
        )
    }

    private func isScopeDisabled(_ scope: ImageEditorExportScope) -> Bool {
        switch scope {
        case .composited:
            false
        case .selectedLayer:
            viewModel.exportSettings.format == .psd
                || viewModel.exportSettings.format == .svg
                || !viewModel.canExportSelectedLayer
        case .selectedLayers:
            viewModel.exportSettings.format == .psd
                || viewModel.exportSettings.format == .svg
                || !viewModel.canExportSelectedLayers
        case .selection:
            viewModel.exportSettings.format == .psd
                || viewModel.exportSettings.format == .svg
                || !viewModel.canExportSelection
        case .slice:
            viewModel.exportSettings.format == .psd
                || viewModel.exportSettings.format == .svg
                || !viewModel.canExportNamedSlice
        }
    }

    private var scaleBinding: Binding<Double> {
        Binding(
            get: { viewModel.exportSettings.scale },
            set: { viewModel.exportSettings.scale = $0 }
        )
    }

    private var qualityBinding: Binding<Double> {
        Binding(
            get: { viewModel.exportSettings.quality },
            set: { viewModel.exportSettings.quality = $0 }
        )
    }

    private var sliceBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.exportSettings.sliceID },
            set: { viewModel.exportSettings.sliceID = $0 }
        )
    }

    private func batchScaleBinding(for scale: Double) -> Binding<Bool> {
        Binding(
            get: { viewModel.exportSettings.batchScales.contains(scale) },
            set: { isEnabled in
                if isEnabled {
                    viewModel.exportSettings.batchScales.insert(scale)
                } else {
                    viewModel.exportSettings.batchScales.remove(scale)
                }
            }
        )
    }
}
