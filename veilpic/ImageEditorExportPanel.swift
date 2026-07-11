//
//  ImageEditorExportPanel.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import SwiftUI

struct ImageEditorExportPanel: View {
    @ObservedObject var viewModel: ImageEditorViewModel

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
                Picker(L10n.text("imageEditor.export.format"), selection: formatBinding) {
                    ForEach(ImageEditorExportFormat.allCases) { format in
                        Text(format.title)
                            .tag(format)
                            .disabled(format == .svg && !viewModel.canExportSVG)
                    }
                }
                .pickerStyle(.menu)

                Picker(L10n.text("imageEditor.export.scope"), selection: scopeBinding) {
                    ForEach(ImageEditorExportScope.allCases) { scope in
                        Text(scope.title)
                            .tag(scope)
                            .disabled(isScopeDisabled(scope))
                    }
                }
                .pickerStyle(.segmented)

                Picker(L10n.text("imageEditor.export.namingRule"), selection: namingRuleBinding) {
                    ForEach(ImageEditorExportNamingRule.allCases) { rule in
                        Text(rule.title).tag(rule)
                    }
                }
                .pickerStyle(.menu)

                if viewModel.exportSettings.usesScale {
                    Stepper(
                        L10n.format("imageEditor.export.scaleValue", viewModel.exportSettings.scale),
                        value: scaleBinding,
                        in: 0.25...4,
                        step: 0.25
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.text("imageEditor.export.batchScales"))
                            .font(.system(size: 12, weight: .semibold))
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
                    HStack {
                        Text(L10n.text("imageEditor.export.quality"))
                            .font(.system(size: 12, weight: .semibold))
                        Slider(value: qualityBinding, in: 0.1...1, step: 0.05)
                        Text(L10n.format("imageEditor.export.qualityValue", Int((viewModel.exportSettings.quality * 100).rounded())))
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .frame(width: 44, alignment: .trailing)
                    }
                }

                HStack {
                    Text(L10n.text("imageEditor.export.outputSize"))
                    Spacer()
                    Text(viewModel.exportSizeText)
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                }
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
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
        .frame(width: 440)
        .background(Color(nsColor: ImageEditorTheme.panel))
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
            set: { viewModel.exportSettings.scope = $0 }
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
