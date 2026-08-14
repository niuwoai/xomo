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

enum ImageEditorPreviewBackdrop: String, CaseIterable, Identifiable, Hashable {
    case checkerboard
    case white
    case black

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.preview.background.\(rawValue)")
    }

    var solidColor: NSColor? {
        switch self {
        case .checkerboard:
            return nil
        case .white:
            return .white
        case .black:
            return .black
        }
    }
}

enum ImageEditorPreviewZoomMode: String, CaseIterable, Identifiable, Hashable {
    case fit
    case actualPixels
    case doublePixels

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.preview.zoom.\(rawValue)")
    }

    var usesScrollablePixelCanvas: Bool {
        self != .fit
    }

    var interpolation: Image.Interpolation {
        usesScrollablePixelCanvas ? .none : .high
    }

    func displayedImageSize(canvasSize: CGSize, viewportSize: CGSize) -> CGSize {
        guard canvasSize.width.isFinite,
              canvasSize.height.isFinite,
              viewportSize.width.isFinite,
              viewportSize.height.isFinite,
              canvasSize.width > 0,
              canvasSize.height > 0,
              viewportSize.width > 0,
              viewportSize.height > 0
        else { return .zero }

        switch self {
        case .fit:
            let scale = min(
                viewportSize.width / canvasSize.width,
                viewportSize.height / canvasSize.height
            )
            return CGSize(
                width: canvasSize.width * scale,
                height: canvasSize.height * scale
            )
        case .actualPixels:
            return canvasSize
        case .doublePixels:
            return CGSize(width: canvasSize.width * 2, height: canvasSize.height * 2)
        }
    }
}

struct ImageEditorPreviewPixelSample {
    let point: CGPoint
    let color: NSColor

    var text: String {
        let reading = ImageEditorColorSamplerReading(color: color)
        return L10n.format(
            "imageEditor.preview.sample",
            Int(point.x),
            Int(point.y),
            reading.hexadecimalRGBA
        )
    }

    static func canvasPoint(
        from location: CGPoint,
        displayedSize: CGSize,
        canvasSize: CGSize
    ) -> CGPoint? {
        guard location.x.isFinite,
              location.y.isFinite,
              displayedSize.width.isFinite,
              displayedSize.height.isFinite,
              canvasSize.width.isFinite,
              canvasSize.height.isFinite,
              displayedSize.width > 0,
              displayedSize.height > 0,
              canvasSize.width > 0,
              canvasSize.height > 0,
              location.x >= 0,
              location.y >= 0,
              location.x < displayedSize.width,
              location.y < displayedSize.height
        else { return nil }

        return CGPoint(
            x: min(
                floor(location.x / displayedSize.width * canvasSize.width),
                canvasSize.width - 1
            ),
            y: min(
                floor(location.y / displayedSize.height * canvasSize.height),
                canvasSize.height - 1
            )
        )
    }

    static func sample(
        image: NSImage,
        location: CGPoint,
        displayedSize: CGSize,
        canvasSize: CGSize
    ) -> Self? {
        guard let point = canvasPoint(
            from: location,
            displayedSize: displayedSize,
            canvasSize: canvasSize
        ),
              let color = image.color(
                at: CGPoint(x: point.x + 0.5, y: point.y + 0.5),
                coordinateSize: canvasSize
              )
        else { return nil }
        return Self(point: point, color: color)
    }
}

private struct ImageEditorPreviewBackdropView: View {
    let backdrop: ImageEditorPreviewBackdrop

    var body: some View {
        if let solidColor = backdrop.solidColor {
            Color(nsColor: solidColor)
        } else {
            Canvas { context, size in
                let square: CGFloat = 12
                let light = Color(nsColor: NSColor(calibratedWhite: 0.94, alpha: 1))
                let dark = Color(nsColor: NSColor(calibratedWhite: 0.72, alpha: 1))
                var y: CGFloat = 0
                var row = 0
                while y < size.height {
                    var x: CGFloat = 0
                    var column = 0
                    while x < size.width {
                        let rect = CGRect(x: x, y: y, width: square, height: square)
                        let color = (row + column).isMultiple(of: 2) ? light : dark
                        context.fill(Path(rect), with: .color(color))
                        x += square
                        column += 1
                    }
                    y += square
                    row += 1
                }
            }
        }
    }
}

struct ImageEditorPreviewPanel: View {
    @ObservedObject var viewModel: ImageEditorViewModel
    @State private var pixelSample: ImageEditorPreviewPixelSample?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(L10n.text("imageEditor.preview.title"), systemImage: "eye")
                    .font(.system(size: 15, weight: .bold))
                    .accessibilityIdentifier("image-editor-preview-panel")
                Spacer()
                Picker(
                    L10n.text("imageEditor.preview.background"),
                    selection: $viewModel.previewBackdrop
                ) {
                    ForEach(ImageEditorPreviewBackdrop.allCases) { backdrop in
                        Text(backdrop.title).tag(backdrop)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 220)
                .accessibilityIdentifier("image-editor-preview-background")
                Picker(
                    L10n.text("imageEditor.preview.zoom"),
                    selection: $viewModel.previewZoomMode
                ) {
                    ForEach(ImageEditorPreviewZoomMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 150)
                .accessibilityIdentifier("image-editor-preview-zoom")
                Button {
                    viewModel.isPreviewSheetPresented = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help(L10n.text("imageEditor.action.cancel"))
                .accessibilityIdentifier("image-editor-preview-close")
            }
            .padding(16)

            Divider()

            GeometryReader { geometry in
                let canvasSize = viewModel.document.canvasSize
                let displayedSize = viewModel.previewZoomMode.displayedImageSize(
                    canvasSize: canvasSize,
                    viewportSize: geometry.size
                )
                if viewModel.previewZoomMode.usesScrollablePixelCanvas {
                    ScrollView([.horizontal, .vertical]) {
                        ZStack {
                            Color(nsColor: ImageEditorTheme.window)
                            previewCanvas(
                                size: displayedSize,
                                interpolation: viewModel.previewZoomMode.interpolation
                            )
                        }
                        .frame(
                            width: max(displayedSize.width, geometry.size.width),
                            height: max(displayedSize.height, geometry.size.height)
                        )
                    }
                } else {
                    ZStack {
                        ImageEditorPreviewBackdropView(backdrop: viewModel.previewBackdrop)
                        previewImage(
                            size: displayedSize,
                            interpolation: viewModel.previewZoomMode.interpolation
                        )
                    }
                }
            }
            .accessibilityIdentifier("image-editor-preview-image")

            Divider()

            HStack(spacing: 10) {
                Text(
                    L10n.format(
                        "imageEditor.preview.dimensions",
                        Int(viewModel.document.canvasSize.width.rounded()),
                        Int(viewModel.document.canvasSize.height.rounded())
                    )
                )
                Spacer()
                if let pixelSample {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: pixelSample.color))
                        .overlay {
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color(nsColor: ImageEditorTheme.border), lineWidth: 1)
                        }
                        .frame(width: 18, height: 18)
                    Text(pixelSample.text)
                        .monospacedDigit()
                        .accessibilityIdentifier("image-editor-preview-pixel-sample")
                } else {
                    Text(L10n.text("imageEditor.preview.sample.empty"))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                }
            }
            .font(.system(size: 11))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .accessibilityIdentifier("image-editor-preview-inspector")
        }
        .frame(minWidth: 640, minHeight: 480)
        .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
        .environment(\.colorScheme, .dark)
        .background(Color(nsColor: ImageEditorTheme.panel))
        .onChange(of: viewModel.previewZoomMode) { _ in
            pixelSample = nil
        }
        .onDisappear {
            pixelSample = nil
        }
    }

    private func previewCanvas(
        size: CGSize,
        interpolation: Image.Interpolation
    ) -> some View {
        ZStack {
            ImageEditorPreviewBackdropView(backdrop: viewModel.previewBackdrop)
            previewImage(size: size, interpolation: interpolation)
        }
        .frame(width: size.width, height: size.height)
    }

    private func previewImage(
        size: CGSize,
        interpolation: Image.Interpolation
    ) -> some View {
        Image(nsImage: viewModel.previewImage)
            .resizable()
            .interpolation(interpolation)
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case let .active(location):
                    pixelSample = ImageEditorPreviewPixelSample.sample(
                        image: viewModel.previewImage,
                        location: location,
                        displayedSize: size,
                        canvasSize: viewModel.document.canvasSize
                    )
                case .ended:
                    pixelSample = nil
                }
            }
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
                    .accessibilityIdentifier("image-editor-export-panel")
                Spacer()
                Button {
                    viewModel.isExportSheetPresented = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help(L10n.text("imageEditor.action.cancel"))
                .accessibilityIdentifier("image-editor-export-close")
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
                            in: ImageEditorExportSettings.supportedScaleRange,
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
            set: { sliceID in
                guard let sliceID else {
                    viewModel.exportSettings.sliceID = nil
                    viewModel.exportSettings.filenameSuffix = ""
                    return
                }
                _ = viewModel.selectSlice(id: sliceID)
            }
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
