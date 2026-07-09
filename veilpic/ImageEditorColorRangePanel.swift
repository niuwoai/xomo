//
//  ImageEditorColorRangePanel.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import SwiftUI

struct ImageEditorColorRangePanel: View {
    @ObservedObject var viewModel: ImageEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            previewStrip
            controls
            footer
        }
        .padding(18)
        .frame(width: 560)
        .background(Color(nsColor: ImageEditorTheme.panel))
    }

    private var header: some View {
        HStack {
            Label(L10n.text("imageEditor.colorRange.title"), systemImage: "eyedropper")
                .font(.system(size: 15, weight: .bold))
            Spacer()
            Button {
                viewModel.isColorRangeSheetPresented = false
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help(L10n.text("imageEditor.action.cancel"))
        }
    }

    private var previewStrip: some View {
        HStack(spacing: 12) {
            sourcePreviewPane
            previewPane(
                titleKey: "imageEditor.colorRange.selectionPreview",
                image: viewModel.colorRangePreviewImage
            )
        }
    }

    private var sourcePreviewPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("imageEditor.colorRange.sourcePreview"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            GeometryReader { geometry in
                ZStack {
                    Color(nsColor: ImageEditorTheme.window)
                    Image(nsImage: viewModel.currentImage)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            guard let imagePoint = previewImagePoint(
                                from: value.location,
                                in: geometry.size,
                                imageSize: viewModel.currentImage.size
                            ) else { return }
                            viewModel.sampleColorRangeColor(at: imagePoint)
                        }
                )
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color(nsColor: ImageEditorTheme.border).opacity(0.75), lineWidth: 1)
            }
        }
    }

    private func previewPane(titleKey: String, image: NSImage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text(titleKey))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            ZStack {
                Color(nsColor: ImageEditorTheme.window)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color(nsColor: ImageEditorTheme.border).opacity(0.75), lineWidth: 1)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            ColorPicker(
                L10n.text("imageEditor.colorRange.sampleColor"),
                selection: colorBinding,
                supportsOpacity: false
            )

            HStack(spacing: 8) {
                ForEach(ImageEditorColorRangeSampleMode.allCases) { mode in
                    sampleModeButton(mode)
                }
                Spacer()
                Text(L10n.format(
                    "imageEditor.colorRange.sampleCount",
                    viewModel.colorRangeIncludeColors.count,
                    viewModel.colorRangeExcludeColors.count
                ))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }

            sampleSwatches

            HStack(spacing: 10) {
                Text(L10n.text("imageEditor.colorRange.fuzziness"))
                    .font(.system(size: 12, weight: .semibold))
                Slider(value: $viewModel.colorRangeTolerance, in: 0...1, step: 0.01)
                Text(L10n.format("imageEditor.colorRange.fuzzinessValue", viewModel.colorRangeTolerance))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .frame(width: 48, alignment: .trailing)
            }

            Toggle(L10n.text("imageEditor.colorRange.invert"), isOn: $viewModel.colorRangeInverted)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(L10n.text("imageEditor.action.cancel")) {
                viewModel.isColorRangeSheetPresented = false
            }
            .buttonStyle(.bordered)

            Button(L10n.text("imageEditor.action.applySelection")) {
                viewModel.applyColorRangeSelectionFromPanel()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: viewModel.colorRangeColor) },
            set: { newColor in
                viewModel.setColorRangePrimaryColor(NSColor(newColor))
            }
        )
    }

    private var sampleSwatches: some View {
        HStack(spacing: 6) {
            ForEach(Array(viewModel.colorRangeIncludeColors.enumerated()), id: \.offset) { _, color in
                colorSwatch(color, isExcluded: false)
            }
            ForEach(Array(viewModel.colorRangeExcludeColors.enumerated()), id: \.offset) { _, color in
                colorSwatch(color, isExcluded: true)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 18)
    }

    private func sampleModeButton(_ mode: ImageEditorColorRangeSampleMode) -> some View {
        Button {
            viewModel.colorRangeSampleMode = mode
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "eyedropper")
                    .font(.system(size: 13, weight: .semibold))
                if mode == .add {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 8, weight: .bold))
                        .offset(x: 5, y: 4)
                } else if mode == .subtract {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 8, weight: .bold))
                        .offset(x: 5, y: 4)
                }
            }
            .frame(width: 28, height: 24)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(viewModel.colorRangeSampleMode == mode ? Color.accentColor : Color(nsColor: ImageEditorTheme.panelRaised))
        .help(mode.title)
    }

    private func colorSwatch(_ color: NSColor, isExcluded: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color(nsColor: color))
            .frame(width: 18, height: 18)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color(nsColor: ImageEditorTheme.border), lineWidth: 1)
            }
            .overlay {
                if isExcluded {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.7), radius: 1)
                }
            }
    }

    private func previewImagePoint(
        from location: CGPoint,
        in size: CGSize,
        imageSize: CGSize
    ) -> CGPoint? {
        let rect = previewImageRect(in: size, imageSize: imageSize)
        guard rect.contains(location), rect.width > 0, rect.height > 0 else { return nil }
        return CGPoint(
            x: (location.x - rect.minX) / rect.width * imageSize.width,
            y: (rect.maxY - location.y) / rect.height * imageSize.height
        )
    }

    private func previewImageRect(in size: CGSize, imageSize: CGSize) -> CGRect {
        let inset: CGFloat = 6
        let availableSize = CGSize(
            width: max(1, size.width - inset * 2),
            height: max(1, size.height - inset * 2)
        )
        let scale = min(
            availableSize.width / max(imageSize.width, 1),
            availableSize.height / max(imageSize.height, 1)
        )
        let displaySize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        return CGRect(
            x: (size.width - displaySize.width) / 2,
            y: (size.height - displaySize.height) / 2,
            width: displaySize.width,
            height: displaySize.height
        )
    }
}
