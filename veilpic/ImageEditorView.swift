//
//  ImageEditorView.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import SwiftUI

struct ImageEditorView: View {
    @StateObject private var viewModel: ImageEditorViewModel
    @State private var dragPoints: [CGPoint] = []
    @State private var dragStart: CGPoint?
    @State private var dragEnd: CGPoint?
    @State private var lastPanTranslation: CGSize = .zero
    @State private var lastMoveImagePoint: CGPoint?
    @State private var activeResizeHandle: ImageEditorLayerResizeHandle?
    @State private var isRotatingLayer = false
    @State private var layerNameDraft = ""

    init(sourceName: String, image: NSImage, onApply: @escaping (NSImage) -> Void) {
        _viewModel = StateObject(wrappedValue: ImageEditorViewModel(sourceName: sourceName, image: image, onApply: onApply))
    }

    var body: some View {
        VStack(spacing: 0) {
            menuBar
            optionBar
            Divider().overlay(editorBorder)

            HStack(spacing: 0) {
                toolRail
                Divider().overlay(editorBorder)
                canvasWorkspace
                Divider().overlay(editorBorder)
                rightDock
            }

            statusBar
        }
        .frame(minWidth: 1160, minHeight: 720)
        .background(Color(nsColor: ImageEditorTheme.window))
        .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
        .onAppear {
            syncLayerNameDraft()
        }
        .onChange(of: viewModel.document.selectedLayerID) { _, _ in
            syncLayerNameDraft()
        }
        .onChange(of: viewModel.selectedLayerName) { _, _ in
            syncLayerNameDraft()
        }
        .sheet(isPresented: $viewModel.isExportSheetPresented) {
            ImageEditorExportPanel(viewModel: viewModel)
        }
    }

    private var menuBar: some View {
        HStack(spacing: 14) {
            ForEach(["file", "edit", "image", "layer", "select", "filter", "view", "window"], id: \.self) { item in
                Button(L10n.text("imageEditor.menu.\(item)")) {
                    viewModel.statusText = L10n.text("imageEditor.status.menuSoon")
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
            }

            Spacer()

            Button(L10n.text("imageEditor.action.cancel")) {
                closeWindow()
            }
            .buttonStyle(EditorTextButtonStyle())

            Button(L10n.text("imageEditor.action.apply")) {
                viewModel.applyAndClose {
                    closeWindow()
                }
            }
            .buttonStyle(EditorPrimaryButtonStyle())

            Button(L10n.text("imageEditor.action.export")) {
                viewModel.openExportPanel()
            }
            .buttonStyle(EditorTextButtonStyle())
        }
        .frame(height: 42)
        .padding(.horizontal, 14)
        .background(Color(nsColor: ImageEditorTheme.chrome))
    }

    private var optionBar: some View {
        HStack(spacing: 12) {
            Label(viewModel.selectedTool.title, systemImage: viewModel.selectedTool.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 132, alignment: .leading)

            optionSlider(titleKey: "imageEditor.option.size", value: $viewModel.brushSize, range: 1...96, step: 1, suffix: "px")
            optionSlider(titleKey: "imageEditor.option.opacity", value: $viewModel.opacity, range: 0.05...1, step: 0.05, suffix: "")
            optionSlider(titleKey: "imageEditor.option.hardness", value: $viewModel.hardness, range: 0...1, step: 0.05, suffix: "")
            optionSlider(titleKey: "imageEditor.option.feather", value: $viewModel.feather, range: 0...40, step: 1, suffix: "px")

            Spacer()

            Button {
                viewModel.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .disabled(!viewModel.canUndo)
            .help(L10n.text("imageEditor.action.undo"))

            Button {
                viewModel.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .disabled(!viewModel.canRedo)
            .help(L10n.text("imageEditor.action.redo"))
        }
        .frame(height: 48)
        .padding(.horizontal, 12)
        .background(Color(nsColor: ImageEditorTheme.panel))
    }

    private func optionSlider(titleKey: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, step: CGFloat, suffix: String) -> some View {
        HStack(spacing: 6) {
            Text(L10n.text(titleKey))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            Slider(value: value, in: range, step: step)
                .frame(width: 92)
            Text(sliderText(value.wrappedValue, suffix: suffix))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .frame(width: suffix.isEmpty ? 28 : 42, alignment: .leading)
        }
    }

    private func sliderText(_ value: CGFloat, suffix: String) -> String {
        if suffix.isEmpty {
            return String(format: "%.2f", value)
        }
        return "\(Int(value.rounded()))\(suffix)"
    }

    private var toolRail: some View {
        VStack(spacing: 5) {
            ForEach(ImageEditorTool.allCases) { tool in
                Button {
                    viewModel.selectTool(tool)
                } label: {
                    Image(systemName: tool.symbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .opacity(tool.isImplemented ? 1 : 0.46)
                }
                .buttonStyle(EditorIconButtonStyle(isSelected: viewModel.selectedTool == tool))
                .help(tool.isImplemented ? tool.title : L10n.format("imageEditor.tool.soon", tool.title))
            }

            Spacer()

            colorChips
        }
        .frame(width: 56)
        .padding(.vertical, 8)
        .background(Color(nsColor: ImageEditorTheme.chrome))
    }

    private var colorChips: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: viewModel.backgroundColor)
                .frame(width: 24, height: 24)
                .overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                .offset(x: 11, y: 11)

            Color(nsColor: viewModel.foregroundColor)
                .frame(width: 24, height: 24)
                .overlay(Rectangle().stroke(Color.white.opacity(0.86), lineWidth: 1))
        }
        .frame(width: 40, height: 40)
        .padding(.bottom, 2)
    }

    private var canvasWorkspace: some View {
        VStack(spacing: 0) {
            documentTab
            GeometryReader { geometry in
                ZStack {
                    Color(nsColor: ImageEditorTheme.window)
                    checkerboard
                        .frame(width: fittedImageRect(in: geometry.size).width, height: fittedImageRect(in: geometry.size).height)
                        .position(x: fittedImageRect(in: geometry.size).midX, y: fittedImageRect(in: geometry.size).midY)

                    Image(nsImage: viewModel.currentImage)
                        .resizable()
                        .frame(width: fittedImageRect(in: geometry.size).width, height: fittedImageRect(in: geometry.size).height)
                        .position(x: fittedImageRect(in: geometry.size).midX, y: fittedImageRect(in: geometry.size).midY)
                        .shadow(color: .black.opacity(0.46), radius: 12, x: 0, y: 8)

                    selectionOverlay(in: geometry.size)
                    layerTransformOverlay(in: geometry.size)
                    dragOverlay(in: geometry.size)
                }
                .contentShape(Rectangle())
                .gesture(canvasGesture(in: geometry.size))
                .onHover { inside in
                    if !inside {
                        viewModel.updatePointer(nil)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var documentTab: some View {
        HStack(spacing: 8) {
            Label(viewModel.document.sourceName, systemImage: "photo")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(Color(nsColor: ImageEditorTheme.panelRaised))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            Spacer()
            Text(viewModel.zoomText)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
        }
        .frame(height: 42)
        .padding(.horizontal, 12)
        .background(Color(nsColor: ImageEditorTheme.window))
    }

    private var checkerboard: some View {
        Canvas { context, size in
            let square: CGFloat = 14
            let light = Color(nsColor: NSColor(calibratedWhite: 0.78, alpha: 1))
            let dark = Color(nsColor: NSColor(calibratedWhite: 0.58, alpha: 1))
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = 0
                var col = 0
                while x < size.width {
                    let rect = CGRect(x: x, y: y, width: square, height: square)
                    context.fill(Path(rect), with: .color((row + col).isMultiple(of: 2) ? light : dark))
                    x += square
                    col += 1
                }
                y += square
                row += 1
            }
        }
    }

    @ViewBuilder
    private func dragOverlay(in size: CGSize) -> some View {
        if let dragStart, let dragEnd, shouldShowDragRect {
            let start = viewPoint(from: dragStart, in: size)
            let end = viewPoint(from: dragEnd, in: size)
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            Rectangle()
                .stroke(Color(nsColor: ImageEditorTheme.selected), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .background(Color(nsColor: ImageEditorTheme.selected).opacity(0.12))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
    }

    private var shouldShowDragRect: Bool {
        switch viewModel.selectedTool {
        case .crop, .marquee, .rectangle, .ellipse:
            true
        default:
            false
        }
    }

    private func canvasGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let imagePoint = imagePoint(from: value.location, in: size)
                viewModel.updatePointer(imagePoint)

                switch viewModel.selectedTool {
                case .hand:
                    let delta = CGSize(
                        width: value.translation.width - lastPanTranslation.width,
                        height: value.translation.height - lastPanTranslation.height
                    )
                    viewModel.nudgeCanvas(by: delta)
                    lastPanTranslation = value.translation
                case .move:
                    if let imagePoint {
                        if let lastMoveImagePoint {
                            viewModel.moveSelectedLayer(
                                by: CGSize(
                                    width: imagePoint.x - lastMoveImagePoint.x,
                                    height: imagePoint.y - lastMoveImagePoint.y
                                )
                            )
                        } else {
                            viewModel.beginMovingSelectedLayer()
                        }
                        lastMoveImagePoint = imagePoint
                    }
                case .brush, .eraser:
                    if let imagePoint {
                        dragPoints.append(imagePoint)
                    }
                case .crop, .marquee, .rectangle, .ellipse:
                    if dragStart == nil {
                        dragStart = imagePoint
                    }
                    dragEnd = imagePoint
                case .lasso:
                    if let imagePoint {
                        dragPoints.append(imagePoint)
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                let imagePoint = imagePoint(from: value.location, in: size)

                switch viewModel.selectedTool {
                case .move:
                    viewModel.finishMovingSelectedLayer()
                case .marquee:
                    if let dragStart, let imagePoint {
                        viewModel.createRectSelection(from: dragStart, to: imagePoint)
                    }
                case .lasso:
                    viewModel.createLassoSelection(points: dragPoints)
                case .magicWand:
                    viewModel.createMagicSelection(at: imagePoint)
                case .brush:
                    viewModel.drawBrush(points: dragPoints)
                case .eraser:
                    viewModel.drawBrush(points: dragPoints, erase: true)
                case .rectangle:
                    if let dragStart, let imagePoint {
                        viewModel.drawShape(from: dragStart, to: imagePoint, ellipse: false)
                    }
                case .ellipse:
                    if let dragStart, let imagePoint {
                        viewModel.drawShape(from: dragStart, to: imagePoint, ellipse: true)
                    }
                case .crop:
                    if let dragStart, let imagePoint {
                        let rect = CGRect(
                            x: min(dragStart.x, imagePoint.x),
                            y: min(dragStart.y, imagePoint.y),
                            width: abs(imagePoint.x - dragStart.x),
                            height: abs(imagePoint.y - dragStart.y)
                        )
                        viewModel.crop(to: rect)
                    }
                case .text:
                    viewModel.addText(at: imagePoint)
                case .eyedropper:
                    if let imagePoint {
                        viewModel.sampleColor(at: imagePoint)
                    }
                case .gradient:
                    viewModel.addGradient()
                case .zoom:
                    viewModel.zoomIn()
                default:
                    break
                }

                dragPoints = []
                dragStart = nil
                dragEnd = nil
                lastPanTranslation = .zero
                lastMoveImagePoint = nil
                activeResizeHandle = nil
            }
    }

    private func fittedImageRect(in size: CGSize) -> CGRect {
        let imageSize = viewModel.currentImage.size
        let baseScale = min(size.width / max(imageSize.width, 1), size.height / max(imageSize.height, 1)) * 0.74
        let scale = max(0.01, baseScale * viewModel.zoom)
        let displaySize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (size.width - displaySize.width) / 2 + viewModel.canvasOffset.width,
            y: (size.height - displaySize.height) / 2 + viewModel.canvasOffset.height,
            width: displaySize.width,
            height: displaySize.height
        )
    }

    private func imagePoint(from viewPoint: CGPoint, in size: CGSize) -> CGPoint? {
        let rect = fittedImageRect(in: size)
        guard rect.contains(viewPoint), rect.width > 0, rect.height > 0 else { return nil }
        let imageSize = viewModel.currentImage.size
        return CGPoint(
            x: (viewPoint.x - rect.minX) / rect.width * imageSize.width,
            y: (rect.maxY - viewPoint.y) / rect.height * imageSize.height
        )
    }

    private func unboundedImagePoint(from viewPoint: CGPoint, in size: CGSize) -> CGPoint {
        let rect = fittedImageRect(in: size)
        let imageSize = viewModel.currentImage.size
        return CGPoint(
            x: (viewPoint.x - rect.minX) / max(rect.width, 1) * imageSize.width,
            y: (rect.maxY - viewPoint.y) / max(rect.height, 1) * imageSize.height
        )
    }

    private func viewPoint(from imagePoint: CGPoint, in size: CGSize) -> CGPoint {
        let rect = fittedImageRect(in: size)
        let imageSize = viewModel.currentImage.size
        return CGPoint(
            x: rect.minX + imagePoint.x / max(imageSize.width, 1) * rect.width,
            y: rect.maxY - imagePoint.y / max(imageSize.height, 1) * rect.height
        )
    }

    private var rightDock: some View {
        VStack(spacing: 0) {
            navigatorPanel
            Divider().overlay(editorBorder)
            historyPanel
            Divider().overlay(editorBorder)
            layersPanel
            Divider().overlay(editorBorder)
            propertiesPanel
        }
        .frame(width: 316)
        .background(Color(nsColor: ImageEditorTheme.panel))
    }

    private var navigatorPanel: some View {
        EditorPanel(title: L10n.text("imageEditor.panel.navigator")) {
            VStack(alignment: .leading, spacing: 8) {
                Image(nsImage: viewModel.currentImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 92)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                Text(viewModel.sizeText)
                Text(viewModel.colorText)
            }
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
        }
        .frame(height: 174)
    }

    private var historyPanel: some View {
        EditorPanel(title: L10n.text("imageEditor.panel.history")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.document.history) { entry in
                        Button {
                            viewModel.restoreHistoryEntry(entry.id)
                        } label: {
                            Label(entry.title, systemImage: historyIconName(for: entry))
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(historyRowBackground(for: entry))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help(L10n.text("imageEditor.action.historyRestore"))
                    }
                }
            }
        }
        .frame(height: 164)
    }

    private func historyIconName(for entry: ImageEditorHistoryEntry) -> String {
        viewModel.document.history.last?.id == entry.id ? "checkmark.circle.fill" : "clock.arrow.circlepath"
    }

    private func historyRowBackground(for entry: ImageEditorHistoryEntry) -> Color {
        viewModel.document.history.last?.id == entry.id
            ? Color(nsColor: ImageEditorTheme.selected).opacity(0.32)
            : Color.white.opacity(0.04)
    }

    private var layersPanel: some View {
        EditorPanel(title: L10n.text("imageEditor.panel.layers")) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Picker("", selection: selectedLayerBlendModeBinding) {
                        ForEach(ImageEditorBlendMode.allCases) { blendMode in
                            Text(blendMode.title).tag(blendMode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 136)

                    Text(L10n.text("imageEditor.option.opacity"))
                    Text("\(Int((viewModel.selectedLayerOpacity * 100).rounded()))%")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
                .font(.system(size: 11, weight: .medium))

                Slider(value: selectedLayerOpacityBinding, in: 0...1, step: 0.05) {
                    Text(L10n.text("imageEditor.option.opacity"))
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text("100")
                } onEditingChanged: { editing in
                    if !editing {
                        viewModel.commitSelectedLayerOpacityChange()
                    }
                }
                .font(.system(size: 10, weight: .medium).monospacedDigit())

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        layerActionButton(systemImage: "plus", helpKey: "imageEditor.action.layerNew") {
                            viewModel.addLayer()
                        }
                        layerActionButton(systemImage: "photo.badge.plus", helpKey: "imageEditor.action.layerImport") {
                            viewModel.chooseImageLayerFile()
                        }
                        layerActionButton(systemImage: "square.grid.3x3.fill", helpKey: "imageEditor.action.layerRasterize") {
                            viewModel.rasterizeSelectedLayer()
                        }
                        .disabled(!viewModel.canRasterizeSelectedLayer)
                        layerActionButton(systemImage: "folder.badge.plus", helpKey: "imageEditor.action.layerGroupNew") {
                            viewModel.addLayerGroup()
                        }
                        layerActionButton(systemImage: "rectangle.stack.badge.plus", helpKey: "imageEditor.action.layerGroupSelected") {
                            viewModel.groupSelectedLayer()
                        }
                        .disabled(!viewModel.canGroupSelectedLayer)
                        layerActionButton(systemImage: "doc.on.doc", helpKey: "imageEditor.action.layerDuplicate") {
                            viewModel.duplicateSelectedLayer()
                        }
                        layerActionButton(systemImage: "trash", helpKey: "imageEditor.action.layerDelete") {
                            viewModel.deleteSelectedLayer()
                        }
                        .disabled(!viewModel.canDeleteLayer)
                        layerActionButton(systemImage: "arrow.up.to.line", helpKey: "imageEditor.action.layerTop") {
                            viewModel.moveSelectedLayerToTop()
                        }
                        .disabled(!viewModel.canMoveSelectedLayerToTop)
                        layerActionButton(systemImage: "arrow.up", helpKey: "imageEditor.action.layerUp") {
                            viewModel.moveSelectedLayerUp()
                        }
                        .disabled(!viewModel.canMoveSelectedLayerUp)
                        layerActionButton(systemImage: "arrow.down", helpKey: "imageEditor.action.layerDown") {
                            viewModel.moveSelectedLayerDown()
                        }
                        .disabled(!viewModel.canMoveSelectedLayerDown)
                        layerActionButton(systemImage: "arrow.down.to.line", helpKey: "imageEditor.action.layerBottom") {
                            viewModel.moveSelectedLayerToBottom()
                        }
                        .disabled(!viewModel.canMoveSelectedLayerToBottom)
                        layerActionButton(systemImage: "square.stack.3d.down.right", helpKey: "imageEditor.action.layerMergeDown") {
                            viewModel.mergeSelectedLayerDown()
                        }
                        .disabled(!viewModel.canMergeSelectedLayerDown)
                        layerActionButton(systemImage: "square.stack.3d.down.right.fill", helpKey: "imageEditor.action.layerMergeVisible") {
                            viewModel.mergeVisibleLayers()
                        }
                        .disabled(!viewModel.canMergeVisibleLayers)
                        layerActionButton(systemImage: "square.stack.3d.up.fill", helpKey: "imageEditor.action.layerStampVisible") {
                            viewModel.stampVisibleLayers()
                        }
                        .disabled(!viewModel.canStampVisibleLayers)
                        layerActionButton(systemImage: "rectangle.fill", helpKey: "imageEditor.action.layerFlatten") {
                            viewModel.flattenImage()
                        }
                        .disabled(!viewModel.canFlattenImage)
                        layerActionButton(systemImage: "circle.dashed", helpKey: "imageEditor.action.layerMaskAdd") {
                            viewModel.addLayerMask()
                        }
                        .disabled(!viewModel.canAddLayerMask)
                        layerActionButton(systemImage: "circle.lefthalf.filled", helpKey: "imageEditor.action.layerMaskFromSelection") {
                            viewModel.addLayerMaskFromSelection()
                        }
                        .disabled(!viewModel.canCreateLayerMaskFromSelection)
                        layerActionButton(systemImage: "paintbrush", helpKey: "imageEditor.action.layerMaskEdit") {
                            viewModel.editLayerMask()
                        }
                        .disabled(!viewModel.selectedLayerHasMask)
                        layerActionButton(systemImage: "arrow.triangle.2.circlepath", helpKey: "imageEditor.action.layerMaskInvert") {
                            viewModel.invertLayerMask()
                        }
                        .disabled(!viewModel.canInvertLayerMask)
                        layerActionButton(systemImage: "checkmark.square", helpKey: "imageEditor.action.layerMaskApply") {
                            viewModel.applyLayerMask()
                        }
                        .disabled(!viewModel.canApplyLayerMask)
                        layerActionButton(systemImage: "xmark.square", helpKey: "imageEditor.action.layerMaskDelete") {
                            viewModel.deleteLayerMask()
                        }
                        .disabled(!viewModel.canDeleteLayerMask)
                        layerActionButton(
                            systemImage: "f.cursive",
                            helpKey: "imageEditor.action.layerStroke",
                            isSelected: viewModel.selectedLayerHasStroke
                        ) {
                            viewModel.toggleSelectedLayerStroke()
                        }
                        layerActionButton(
                            systemImage: "sparkles",
                            helpKey: "imageEditor.action.layerShadow",
                            isSelected: viewModel.selectedLayerHasShadow
                        ) {
                            viewModel.toggleSelectedLayerShadow()
                        }
                        layerActionButton(
                            systemImage: "arrow.down.to.line.compact",
                            helpKey: "imageEditor.action.layerClippingMask",
                            isSelected: viewModel.selectedLayerIsClippingMask
                        ) {
                            viewModel.toggleSelectedLayerClippingMask()
                        }
                        .disabled(!viewModel.canToggleSelectedLayerClippingMask)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.selectedLayerCount > 1 {
                    Text(L10n.format("imageEditor.layer.selectionCount", viewModel.selectedLayerCount))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array(viewModel.document.layers.reversed())) { layer in
                            layerRow(layer)
                        }
                    }
                }
            }
        }
        .frame(height: 246)
    }

    private func layerActionButton(
        systemImage: String,
        helpKey: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(EditorIconButtonStyle(isSelected: isSelected))
        .help(L10n.text(helpKey))
    }

    private func layerRow(_ layer: ImageEditorLayer) -> some View {
        HStack(spacing: 8) {
            if layer.groupID != nil {
                Spacer()
                    .frame(width: 14)
            }

            Button {
                viewModel.toggleLayerVisibility(layer.id)
            } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .frame(width: 18, height: 22)
            }
            .buttonStyle(.plain)
            .help(L10n.text("imageEditor.action.layerVisibility"))

            Button {
                let flags = NSEvent.modifierFlags
                viewModel.selectLayer(
                    layer.id,
                    editingMask: false,
                    extendingSelection: flags.contains(.command) || flags.contains(.shift)
                )
            } label: {
                HStack(spacing: 8) {
                    Image(nsImage: layer.thumbnail())
                                .resizable()
                                .scaledToFill()
                                .frame(width: 34, height: 26)
                                .clipped()
                                .background(Color.white.opacity(0.18))
                                .overlay(Rectangle().stroke(contentThumbnailStroke(for: layer), lineWidth: 1.4))

                    if let maskThumbnail = layer.maskThumbnail() {
                        Button {
                            viewModel.selectLayer(layer.id, editingMask: true)
                        } label: {
                            Image(nsImage: maskThumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 24, height: 24)
                                .clipped()
                                .background(Color.black.opacity(0.24))
                                .overlay(Rectangle().stroke(maskThumbnailStroke(for: layer), lineWidth: 1.4))
                        }
                        .buttonStyle(.plain)
                        .help(L10n.text("imageEditor.action.layerMaskEdit"))
                    }

                    Text(layer.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    Spacer()

                    if layer.isGroup {
                        Text(L10n.text("imageEditor.layer.groupBadge"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            .lineLimit(1)
                    } else if layer.isAdjustment {
                        Text(L10n.text("imageEditor.layer.adjustmentBadge"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            .lineLimit(1)
                    } else if layer.isFilter {
                        Text(L10n.text("imageEditor.layer.filterBadge"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            .lineLimit(1)
                    } else if layer.isText {
                        Text(L10n.text("imageEditor.layer.textBadge"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            .lineLimit(1)
                    } else if layer.blendMode != .normal {
                        Text(layer.blendMode.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            .lineLimit(1)
                    }

                    if layer.isClippingMask {
                        Text(L10n.text("imageEditor.layer.clippingBadge"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(nsColor: ImageEditorTheme.selected).opacity(0.52))
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }

                    if layer.hasLayerEffects {
                        Text("fx")
                            .font(.system(size: 10, weight: .bold, design: .serif))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(nsColor: ImageEditorTheme.selected).opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }

                    Text("\(Int((layer.opacity * 100).rounded()))%")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                }
            }
            .buttonStyle(.plain)

            Button {
                viewModel.toggleLayerLock(layer.id)
            } label: {
                Image(systemName: layer.isLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 16, height: 22)
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }
            .buttonStyle(.plain)
            .help(L10n.text(layer.isLocked ? "imageEditor.action.layerUnlock" : "imageEditor.action.layerLock"))
        }
        .padding(8)
        .background(Color(nsColor: ImageEditorTheme.selected).opacity(viewModel.isLayerSelected(layer.id) ? 0.45 : 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private func contentThumbnailStroke(for layer: ImageEditorLayer) -> Color {
        let selected = viewModel.isPrimaryLayer(layer.id) && !viewModel.isEditingLayerMask
        return selected ? Color.white.opacity(0.9) : Color.white.opacity(0.18)
    }

    private func maskThumbnailStroke(for layer: ImageEditorLayer) -> Color {
        let selected = viewModel.isPrimaryLayer(layer.id) && viewModel.isEditingLayerMask
        return selected ? Color(nsColor: ImageEditorTheme.selected) : Color.white.opacity(0.22)
    }

    private var selectedLayerOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerOpacity
        } set: { value in
            viewModel.setSelectedLayerOpacity(value)
        }
    }

    private var selectedLayerBlendModeBinding: Binding<ImageEditorBlendMode> {
        Binding {
            viewModel.selectedLayerBlendMode
        } set: { value in
            viewModel.setSelectedLayerBlendMode(value)
        }
    }

    private func syncLayerNameDraft() {
        layerNameDraft = viewModel.selectedLayerName
    }

    private func commitLayerNameDraft() {
        viewModel.renameSelectedLayer(to: layerNameDraft)
        syncLayerNameDraft()
    }

    private var selectedLayerStrokeWidthBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerStrokeWidth
        } set: { value in
            viewModel.setSelectedLayerStrokeWidth(value)
        }
    }

    private var selectedLayerShadowOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerShadowOpacity
        } set: { value in
            viewModel.setSelectedLayerShadowOpacity(value)
        }
    }

    private var selectedLayerShadowBlurBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerShadowBlur
        } set: { value in
            viewModel.setSelectedLayerShadowBlur(value)
        }
    }

    private var selectedLayerShadowOffsetXBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerShadowOffsetX
        } set: { value in
            viewModel.setSelectedLayerShadowOffsetX(value)
        }
    }

    private var selectedLayerShadowOffsetYBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerShadowOffsetY
        } set: { value in
            viewModel.setSelectedLayerShadowOffsetY(value)
        }
    }

    @ViewBuilder
    private func selectionOverlay(in size: CGSize) -> some View {
        let activeLasso = viewModel.selectedTool == .lasso && dragPoints.count > 1
        if let selection = viewModel.selection ?? (activeLasso ? ImageEditorSelection.polygon(dragPoints) : nil) {
            Canvas { context, _ in
                let converted = selection.points.map { viewPoint(from: $0, in: size) }
                guard let first = converted.first else { return }
                var path = Path()
                path.move(to: first)
                for point in converted.dropFirst() {
                    path.addLine(to: point)
                }
                if selection.isPolygon || converted.count == 4 {
                    path.closeSubpath()
                }
                let stroke = StrokeStyle(lineWidth: 1.4, dash: [5, 4])
                context.stroke(path, with: .color(Color.white.opacity(0.92)), style: stroke)
                context.stroke(path, with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.9)), style: StrokeStyle(lineWidth: 1.4, dash: [5, 4], dashPhase: 4))
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func layerTransformOverlay(in size: CGSize) -> some View {
        if let layerFrame = viewModel.selectedLayerTransformFrame {
            let rect = viewRect(from: layerFrame, in: size)
            Rectangle()
                .stroke(Color(nsColor: ImageEditorTheme.selected), style: StrokeStyle(lineWidth: 1.6, dash: [7, 4]))
                .frame(width: max(1, rect.width), height: max(1, rect.height))
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)

            if viewModel.canResizeSelectedLayer {
                ForEach(ImageEditorLayerResizeHandle.allCases) { handle in
                    resizeHandleView(handle: handle, in: rect, canvasSize: size)
                }
            }

            if viewModel.canRotateSelectedLayer {
                rotateHandleView(in: rect, canvasSize: size)
            }
        }
    }

    private func resizeHandleView(
        handle: ImageEditorLayerResizeHandle,
        in rect: CGRect,
        canvasSize: CGSize
    ) -> some View {
        let point = resizeHandleViewPoint(handle, in: rect)
        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color.white.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Color(nsColor: ImageEditorTheme.selected), lineWidth: 1.5)
            )
            .frame(width: 10, height: 10)
            .position(point)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if activeResizeHandle == nil {
                            activeResizeHandle = handle
                            viewModel.beginResizingSelectedLayer(handle: handle)
                        }
                        viewModel.resizeSelectedLayer(
                            to: unboundedImagePoint(from: value.location, in: canvasSize),
                            handle: handle,
                            preservingAspectRatio: NSEvent.modifierFlags.contains(.shift)
                        )
                    }
                    .onEnded { _ in
                        viewModel.finishResizingSelectedLayer()
                        activeResizeHandle = nil
                    }
            )
            .help(L10n.text("imageEditor.action.layerResizeHandle"))
    }

    private func rotateHandleView(
        in rect: CGRect,
        canvasSize: CGSize
    ) -> some View {
        let topPoint = CGPoint(x: rect.midX, y: rect.minY)
        let handlePoint = rotateHandleViewPoint(in: rect)
        return ZStack {
            Path { path in
                path.move(to: topPoint)
                path.addLine(to: handlePoint)
            }
            .stroke(Color(nsColor: ImageEditorTheme.selected).opacity(0.75), lineWidth: 1.4)
            .allowsHitTesting(false)

            Circle()
                .fill(Color.white.opacity(0.96))
                .overlay(
                    Circle()
                        .stroke(Color(nsColor: ImageEditorTheme.selected), lineWidth: 1.6)
                )
                .frame(width: 14, height: 14)
                .position(handlePoint)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isRotatingLayer {
                                isRotatingLayer = true
                                viewModel.beginRotatingSelectedLayer(
                                    from: unboundedImagePoint(from: value.startLocation, in: canvasSize)
                                )
                            }
                            viewModel.rotateSelectedLayer(
                                to: unboundedImagePoint(from: value.location, in: canvasSize),
                                snappingToStep: NSEvent.modifierFlags.contains(.shift)
                            )
                        }
                        .onEnded { _ in
                            viewModel.finishRotatingSelectedLayer()
                            isRotatingLayer = false
                        }
                )
                .help(L10n.text("imageEditor.action.layerRotateHandle"))
        }
    }

    private func viewRect(from imageRect: CGRect, in size: CGSize) -> CGRect {
        let minPoint = viewPoint(from: CGPoint(x: imageRect.minX, y: imageRect.minY), in: size)
        let maxPoint = viewPoint(from: CGPoint(x: imageRect.maxX, y: imageRect.maxY), in: size)
        return CGRect(
            x: min(minPoint.x, maxPoint.x),
            y: min(minPoint.y, maxPoint.y),
            width: abs(maxPoint.x - minPoint.x),
            height: abs(maxPoint.y - minPoint.y)
        )
    }

    private func resizeHandleViewPoint(_ handle: ImageEditorLayerResizeHandle, in rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft:
            CGPoint(x: rect.minX, y: rect.minY)
        case .top:
            CGPoint(x: rect.midX, y: rect.minY)
        case .topRight:
            CGPoint(x: rect.maxX, y: rect.minY)
        case .left:
            CGPoint(x: rect.minX, y: rect.midY)
        case .right:
            CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomLeft:
            CGPoint(x: rect.minX, y: rect.maxY)
        case .bottom:
            CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomRight:
            CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    private func rotateHandleViewPoint(in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.minY - 32)
    }

    private var propertiesPanel: some View {
        EditorPanel(title: L10n.text("imageEditor.panel.properties")) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("imageEditor.properties.layerName"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                HStack(spacing: 8) {
                    TextField(L10n.text("imageEditor.properties.layerNamePlaceholder"), text: $layerNameDraft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            commitLayerNameDraft()
                        }

                    Button(L10n.text("imageEditor.action.layerRename")) {
                        commitLayerNameDraft()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                    .disabled(layerNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Divider().overlay(editorBorder)

                Picker(L10n.text("imageEditor.properties.adjustment"), selection: $viewModel.selectedAdjustment) {
                    ForEach(ImageEditorAdjustment.allCases) { adjustment in
                        Text(adjustment.title).tag(adjustment)
                    }
                }
                Slider(value: $viewModel.adjustmentValue, in: -1...1, step: 0.05)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Button(L10n.text("imageEditor.action.applyAdjustment")) {
                            viewModel.applyAdjustment()
                        }
                        .buttonStyle(EditorPrimaryButtonStyle())
                        Button(L10n.text("imageEditor.action.layerAdjustmentNew")) {
                            viewModel.addAdjustmentLayer()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        if viewModel.selectedLayerIsAdjustment {
                            Button(L10n.text("imageEditor.action.layerAdjustmentUpdate")) {
                                viewModel.updateSelectedAdjustmentLayer()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                        }
                    }
                    HStack {
                        Button(L10n.text("imageEditor.action.selectionFromLayer")) {
                            viewModel.loadSelectionFromLayerTransparency()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.canLoadSelectionFromLayerTransparency)
                        Button(L10n.text("imageEditor.action.cropCenter")) {
                            viewModel.cropCenter()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                    }
                    HStack {
                        if viewModel.hasSelection {
                            Button(L10n.text("imageEditor.action.fillSelection")) {
                                viewModel.fillSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canEditSelectionPixels)
                            Button(L10n.text("imageEditor.action.strokeSelection")) {
                                viewModel.strokeSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canEditSelectionPixels)
                            Button(L10n.text("imageEditor.action.selectionCopyLayer")) {
                                viewModel.copySelectionToNewLayer()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canCopySelectionToNewLayer)
                            Button(L10n.text("imageEditor.action.selectionCutLayer")) {
                                viewModel.cutSelectionToNewLayer()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canCutSelectionToNewLayer)
                        }
                    }
                    HStack {
                        if viewModel.hasSelection {
                            Button(L10n.text("imageEditor.action.clearSelectionPixels")) {
                                viewModel.clearSelectionPixels()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canEditSelectionPixels)
                        }
                    }
                    HStack {
                        if viewModel.hasSelection {
                            Button(L10n.text("imageEditor.action.invertSelection")) {
                                viewModel.invertSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            Button(L10n.text("imageEditor.action.saveSelection")) {
                                viewModel.saveCurrentSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            Button(L10n.text("imageEditor.action.clearSelection")) {
                                viewModel.clearSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                        }
                        Button(L10n.text("imageEditor.action.restoreSelection")) {
                            viewModel.restoreSavedSelection()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.hasSavedSelection)
                    }
                }

                Divider().overlay(editorBorder)

                Picker(L10n.text("imageEditor.properties.filter"), selection: $viewModel.selectedFilter) {
                    ForEach(ImageEditorFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                Slider(value: $viewModel.filterIntensity, in: 0...1, step: 0.05)
                HStack {
                    Button(L10n.text("imageEditor.action.layerFilterNew")) {
                        viewModel.addFilterLayer()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                    if viewModel.selectedLayerIsFilter {
                        Button(L10n.text("imageEditor.action.layerFilterUpdate")) {
                            viewModel.updateSelectedFilterLayer()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                    }
                }

                Divider().overlay(editorBorder)

                TextField(L10n.text("imageEditor.properties.textPlaceholder"), text: $viewModel.textValue)
                    .textFieldStyle(.roundedBorder)
                Stepper(
                    L10n.format("imageEditor.properties.textSizeValue", Int(viewModel.textSize.rounded())),
                    value: $viewModel.textSize,
                    in: 6...240,
                    step: 1
                )
                HStack {
                    Button(L10n.text("imageEditor.action.layerTextNew")) {
                        viewModel.addText()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                    if viewModel.selectedLayerIsText {
                        Button(L10n.text("imageEditor.action.layerTextUpdate")) {
                            viewModel.updateSelectedTextLayer()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                    }
                    Button(L10n.text("imageEditor.action.gradient")) {
                        viewModel.addGradient()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                }

                Divider().overlay(editorBorder)

                HStack {
                    Button {
                        viewModel.scaleSelectedLayer(by: 0.9)
                    } label: {
                        Label(L10n.text("imageEditor.action.layerScaleDown"), systemImage: "minus.magnifyingglass")
                    }
                    .buttonStyle(EditorTextButtonStyle())

                    Button {
                        viewModel.scaleSelectedLayer(by: 1.1)
                    } label: {
                        Label(L10n.text("imageEditor.action.layerScaleUp"), systemImage: "plus.magnifyingglass")
                    }
                    .buttonStyle(EditorTextButtonStyle())
                }

                HStack {
                    Button {
                        viewModel.rotateSelectedLayer(degrees: -15)
                    } label: {
                        Label(L10n.text("imageEditor.action.layerRotateLeft"), systemImage: "rotate.left")
                    }
                    .buttonStyle(EditorTextButtonStyle())

                    Button {
                        viewModel.rotateSelectedLayer(degrees: 15)
                    } label: {
                        Label(L10n.text("imageEditor.action.layerRotateRight"), systemImage: "rotate.right")
                    }
                    .buttonStyle(EditorTextButtonStyle())
                }

                Text(viewModel.selectedLayerGeometryText)
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                Divider().overlay(editorBorder)

                Text(L10n.text("imageEditor.properties.layerStyle"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                Stepper(
                    L10n.format("imageEditor.properties.strokeWidthValue", Int(viewModel.selectedLayerStrokeWidth.rounded())),
                    value: selectedLayerStrokeWidthBinding,
                    in: 1...24,
                    step: 1
                )
                Stepper(
                    L10n.format("imageEditor.properties.shadowOpacityValue", Int((viewModel.selectedLayerShadowOpacity * 100).rounded())),
                    value: selectedLayerShadowOpacityBinding,
                    in: 0.05...1,
                    step: 0.05
                )
                Stepper(
                    L10n.format("imageEditor.properties.shadowBlurValue", Int(viewModel.selectedLayerShadowBlur.rounded())),
                    value: selectedLayerShadowBlurBinding,
                    in: 0...30,
                    step: 1
                )
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.shadowOffsetXValue", Int(viewModel.selectedLayerShadowOffsetX.rounded())),
                        value: selectedLayerShadowOffsetXBinding,
                        in: -40...40,
                        step: 1
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.shadowOffsetYValue", Int(viewModel.selectedLayerShadowOffsetY.rounded())),
                        value: selectedLayerShadowOffsetYBinding,
                        in: -40...40,
                        step: 1
                    )
                }

                Divider().overlay(editorBorder)

                HStack {
                    Button {
                        viewModel.rotateClockwise()
                    } label: {
                        Label(L10n.text("imageEditor.action.rotate"), systemImage: "rotate.right")
                    }
                    .buttonStyle(EditorTextButtonStyle())

                    Button {
                        viewModel.flipHorizontal()
                    } label: {
                        Label(L10n.text("imageEditor.action.flipH"), systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    }
                    .buttonStyle(EditorTextButtonStyle())

                    Button {
                        viewModel.flipVertical()
                    } label: {
                        Label(L10n.text("imageEditor.action.flipV"), systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                    }
                    .buttonStyle(EditorTextButtonStyle())
                }
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Text(viewModel.statusText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Text(viewModel.pointerText)
            Text(viewModel.sizeText)
            Text(viewModel.zoomText)
        }
        .font(.system(size: 11, weight: .medium).monospacedDigit())
        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
        .frame(height: 28)
        .padding(.horizontal, 10)
        .background(Color(nsColor: ImageEditorTheme.chrome))
    }

    private var editorBorder: Color {
        Color(nsColor: ImageEditorTheme.border).opacity(0.65)
    }

    private func closeWindow() {
        NSApplication.shared.keyWindow?.close()
    }
}

private struct EditorPanel<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(nsColor: ImageEditorTheme.chrome))

            content
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct EditorIconButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? .white : Color(nsColor: ImageEditorTheme.text))
            .background(isSelected ? Color(nsColor: ImageEditorTheme.selected) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.16) : Color.clear, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct EditorTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color(nsColor: ImageEditorTheme.panelRaised).opacity(configuration.isPressed ? 0.65 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color(nsColor: ImageEditorTheme.border).opacity(0.8), lineWidth: 1)
            }
    }
}

private struct EditorPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Color(nsColor: ImageEditorTheme.selected).opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            }
    }
}
