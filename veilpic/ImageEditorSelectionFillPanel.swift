//
//  ImageEditorSelectionFillPanel.swift
//  veilpic
//
//  Created by Codex on 2026/8/17.
//

import AppKit
import SwiftUI

struct ImageEditorSelectionFillPanel: View {
    @ObservedObject var viewModel: ImageEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            contentsSection
            blendingSection
            footer
        }
        .padding(18)
        .frame(width: 420)
        .background(Color(nsColor: ImageEditorTheme.panel))
    }

    private var header: some View {
        HStack {
            Label(L10n.text("imageEditor.selectionFill.title"), systemImage: "paintbrush.fill")
                .font(.system(size: 15, weight: .bold))
            Spacer()
            Button {
                viewModel.isSelectionFillSheetPresented = false
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help(L10n.text("imageEditor.action.cancel"))
        }
    }

    private var contentsSection: some View {
        GroupBox(L10n.text("imageEditor.selectionFill.contents")) {
            VStack(alignment: .leading, spacing: 10) {
                Picker(
                    L10n.text("imageEditor.selectionFill.use"),
                    selection: $viewModel.selectionFillContents
                ) {
                    ForEach(ImageEditorSelectionFillContents.allCases) { contents in
                        Text(contents.title).tag(contents)
                    }
                }
                .accessibilityIdentifier("image-editor-fill-contents")

                if viewModel.selectionFillContents == .color {
                    ColorPicker(
                        L10n.text("imageEditor.selectionFill.customColor"),
                        selection: customColorBinding,
                        supportsOpacity: false
                    )
                    .accessibilityIdentifier("image-editor-fill-custom-color")
                }

                if viewModel.selectionFillContents == .pattern {
                    patternControls
                }
            }
            .padding(.top, 4)
        }
    }

    private var patternControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(nsImage: viewModel.selectionFillPatternContent.renderedImage(
                    size: CGSize(width: 52, height: 52)
                ))
                .resizable()
                .interpolation(.none)
                .frame(width: 52, height: 52)
                .background(ImageEditorTransparencyCheckerboard())
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Picker(
                        L10n.text("imageEditor.patternFill.kind"),
                        selection: patternKindBinding
                    ) {
                        ForEach(ImageEditorPatternOverlayKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    ColorPicker(
                        L10n.text("imageEditor.selectionFill.patternColor"),
                        selection: patternColorBinding,
                        supportsOpacity: false
                    )
                }
            }

            patternSlider(
                labelKey: "imageEditor.selectionFill.patternOpacity",
                value: patternOpacityBinding,
                range: 0.05...1,
                valueText: L10n.format(
                    "imageEditor.selectionFill.opacityValue",
                    Int((viewModel.selectionFillPatternContent.opacity * 100).rounded())
                )
            )
            patternSlider(
                labelKey: "imageEditor.patternFill.scale",
                value: patternScaleBinding,
                range: 6...64,
                valueText: L10n.format(
                    "imageEditor.patternFill.scaleValue",
                    Int(viewModel.selectionFillPatternContent.scale.rounded())
                )
            )
            HStack(spacing: 10) {
                Text(L10n.text("imageEditor.selectionFill.patternOffset"))
                TextField(
                    L10n.text("imageEditor.patternFill.offsetX"),
                    value: patternOffsetXBinding,
                    format: .number.precision(.fractionLength(0))
                )
                    .frame(width: 64)
                TextField(
                    L10n.text("imageEditor.patternFill.offsetY"),
                    value: patternOffsetYBinding,
                    format: .number.precision(.fractionLength(0))
                )
                    .frame(width: 64)
            }
            Toggle(
                L10n.text("imageEditor.selectionFill.alignPatternWithCanvas"),
                isOn: $viewModel.selectionFillPatternAlignsWithCanvas
            )
        }
        .accessibilityIdentifier("image-editor-fill-pattern-controls")
    }

    private func patternSlider(
        labelKey: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueText: String
    ) -> some View {
        HStack(spacing: 10) {
            Text(L10n.text(labelKey))
            Slider(value: value, in: range)
            Text(valueText)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .frame(width: 48, alignment: .trailing)
        }
    }

    private var blendingSection: some View {
        GroupBox(L10n.text("imageEditor.selectionFill.blending")) {
            VStack(alignment: .leading, spacing: 12) {
                Picker(
                    L10n.text("imageEditor.selectionFill.mode"),
                    selection: $viewModel.selectionFillBlendMode
                ) {
                    ForEach(ImageEditorBlendMode.smartFilterCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .accessibilityIdentifier("image-editor-fill-blend-mode")

                HStack(spacing: 10) {
                    Text(L10n.text("imageEditor.selectionFill.opacity"))
                    Slider(value: $viewModel.selectionFillOpacity, in: 0...1, step: 0.01)
                    Text(L10n.format(
                        "imageEditor.selectionFill.opacityValue",
                        Int((viewModel.selectionFillOpacity * 100).rounded())
                    ))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .frame(width: 48, alignment: .trailing)
                }

                Toggle(
                    L10n.text("imageEditor.selectionFill.preserveTransparency"),
                    isOn: $viewModel.selectionFillPreservesTransparency
                )
                .disabled(viewModel.isQuickMaskMode)
                .help(viewModel.isQuickMaskMode
                    ? L10n.text("imageEditor.selectionFill.quickMaskTransparencyHelp")
                    : "")
            }
            .padding(.top, 4)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(L10n.text("imageEditor.action.cancel")) {
                viewModel.isSelectionFillSheetPresented = false
            }
            .keyboardShortcut(.cancelAction)
            Button(L10n.text("imageEditor.action.fillSelection")) {
                viewModel.applySelectionFillFromPanel()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canFillCurrentEditingTarget)
        }
    }

    private var customColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: viewModel.selectionFillCustomColor) },
            set: { viewModel.selectionFillCustomColor = NSColor($0) }
        )
    }

    private var patternKindBinding: Binding<ImageEditorPatternOverlayKind> {
        Binding(
            get: { viewModel.selectionFillPatternContent.kind },
            set: { viewModel.selectionFillPatternContent.kind = $0 }
        )
    }

    private var patternColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: viewModel.selectionFillPatternContent.color) },
            set: { color in
                guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return }
                viewModel.selectionFillPatternContent.red = rgb.redComponent
                viewModel.selectionFillPatternContent.green = rgb.greenComponent
                viewModel.selectionFillPatternContent.blue = rgb.blueComponent
            }
        )
    }

    private var patternOpacityBinding: Binding<Double> {
        Binding(
            get: { viewModel.selectionFillPatternContent.opacity },
            set: { viewModel.selectionFillPatternContent.opacity = $0 }
        )
    }

    private var patternScaleBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.selectionFillPatternContent.scale) },
            set: { viewModel.selectionFillPatternContent.scale = CGFloat($0) }
        )
    }

    private var patternOffsetXBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.selectionFillPatternContent.offsetX) },
            set: { viewModel.selectionFillPatternContent.offsetX = CGFloat(max(-128, min(128, $0))) }
        )
    }

    private var patternOffsetYBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.selectionFillPatternContent.offsetY) },
            set: { viewModel.selectionFillPatternContent.offsetY = CGFloat(max(-128, min(128, $0))) }
        )
    }
}
