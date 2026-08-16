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
            }
            .padding(.top, 4)
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
}
