//
//  ImageEditorView.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import SwiftUI

struct ImageEditorView: View {
    @StateObject var viewModel: ImageEditorViewModel
    @State private var dragPoints: [CGPoint] = []
    @State private var dragStart: CGPoint?
    @State private var dragEnd: CGPoint?
    @State private var lastPanTranslation: CGSize = .zero
    @State private var lastMoveImagePoint: CGPoint?
    @State private var activeResizeHandle: ImageEditorLayerResizeHandle?
    @State private var isRotatingLayer = false
    @State private var isMovingPathAnchor = false
    @State private var activeGuideDrag: ImageEditorGuideDrag?
    @State private var layerNameDraft = ""
    @State var layerNameDrafts: [UUID: String] = [:]
    @State var layerSearchQuery = ""
    @State var selectedLayerKindFilter: ImageEditorLayerKindFilter = .all
    @State var selectedLayerLabelFilter: ImageEditorLayerLabelColor?
    @State var selectedLayerStateFilter: ImageEditorLayerStateFilter = .all
    @State var selectedLayerAttributeFilter: ImageEditorLayerAttributeFilter = .all
    @State var alphaChannelNameDrafts: [UUID: String] = [:]
    @State var layerCompNameDrafts: [UUID: String] = [:]
    @State var historySnapshotNameDrafts: [UUID: String] = [:]
    @State var selectedLayerPanelTab: ImageEditorLayerPanelTab = .layers
    @State var targetedLayerDropTarget: ImageEditorLayerDropTarget?

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
            viewModel.syncSizeControlsFromDocument()
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
        .sheet(isPresented: $viewModel.isColorRangeSheetPresented) {
            ImageEditorColorRangePanel(viewModel: viewModel)
        }
    }

    private var optionBar: some View {
        HStack(spacing: 12) {
            Label(viewModel.selectedTool.title, systemImage: viewModel.selectedTool.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 132, alignment: .leading)

            if viewModel.selectedTool.supportsSelectionMode {
                selectionModePicker
            }

            optionSlider(titleKey: "imageEditor.option.size", value: $viewModel.brushSize, range: 1...96, step: 1, suffix: "px")
            optionSlider(titleKey: "imageEditor.option.opacity", value: $viewModel.opacity, range: 0.05...1, step: 0.05, suffix: "")
            optionSlider(titleKey: "imageEditor.option.hardness", value: $viewModel.hardness, range: 0...1, step: 0.05, suffix: "")
            optionSlider(titleKey: "imageEditor.option.feather", value: $viewModel.feather, range: 0...40, step: 1, suffix: "px")
            if viewModel.selectedTool.supportsTolerance {
                optionSlider(titleKey: "imageEditor.option.tolerance", value: $viewModel.tolerance, range: 0...1, step: 0.02, suffix: "")
            }

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

    private var selectionModePicker: some View {
        Picker(L10n.text("imageEditor.option.selectionMode"), selection: $viewModel.selectionMode) {
            ForEach(ImageEditorSelectionMode.allCases) { mode in
                Text(mode.compactTitle)
                    .tag(mode)
                    .help(mode.title)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: 226)
        .help(L10n.text("imageEditor.option.selectionMode"))
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

                    Image(nsImage: viewModel.previewImage)
                        .resizable()
                        .frame(width: fittedImageRect(in: geometry.size).width, height: fittedImageRect(in: geometry.size).height)
                        .position(x: fittedImageRect(in: geometry.size).midX, y: fittedImageRect(in: geometry.size).midY)
                        .shadow(color: .black.opacity(0.46), radius: 12, x: 0, y: 8)

                    gridOverlay(in: geometry.size)
                    guideOverlay(in: geometry.size)
                    guideInteractionOverlay(in: geometry.size)
                    selectionOverlay(in: geometry.size)
                    layerTransformOverlay(in: geometry.size)
                    dragOverlay(in: geometry.size)
                    rulerOverlay(in: geometry.size)
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
        if !viewModel.pendingPenPathPoints.isEmpty {
            let points = viewModel.pendingPenPathPoints.map { viewPoint(from: $0, in: size) }
            Canvas { context, _ in
                guard let first = points.first else { return }
                var path = Path()
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(Color.white.opacity(0.88)), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                context.stroke(path, with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.95)), style: StrokeStyle(lineWidth: 2, dash: [6, 4], dashPhase: 5))
                for (index, point) in points.enumerated() {
                    let radius: CGFloat = index == 0 ? 5 : 4
                    let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(index == 0 ? Color.white : Color(nsColor: ImageEditorTheme.selected)))
                    context.stroke(Path(ellipseIn: rect), with: .color(Color.black.opacity(0.45)), lineWidth: 1)
                }
            }
            .allowsHitTesting(false)
        }

        if let anchorPoints = selectedPathAnchorOverlayPoints(in: size), !anchorPoints.isEmpty {
            Canvas { context, _ in
                for item in anchorPoints {
                    for handle in [item.inHandle, item.outHandle].compactMap({ $0 }) {
                        var handleLine = Path()
                        handleLine.move(to: item.anchor)
                        handleLine.addLine(to: handle)
                        context.stroke(
                            handleLine,
                            with: .color(Color.white.opacity(0.62)),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                    }
                    for handle in [
                        (role: ImageEditorPathControlRole.inHandle, point: item.inHandle),
                        (role: ImageEditorPathControlRole.outHandle, point: item.outHandle)
                    ] {
                        guard let point = handle.point else { continue }
                        let isHandleSelected = item.subpathIndex == viewModel.selectedPathSubpathIndex
                            && item.index == viewModel.selectedPathAnchorIndex
                            && viewModel.selectedPathControlRole == handle.role
                        let rect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                        context.fill(
                            Path(rect),
                            with: .color(isHandleSelected ? Color.white : Color(nsColor: ImageEditorTheme.selected).opacity(0.78))
                        )
                        context.stroke(Path(rect), with: .color(Color.black.opacity(0.55)), lineWidth: 1)
                    }
                    let isAnchorSelected = item.subpathIndex == viewModel.selectedPathSubpathIndex
                        && item.index == viewModel.selectedPathAnchorIndex
                        && viewModel.selectedPathControlRole == .anchor
                    let radius: CGFloat = isAnchorSelected ? 5.5 : 4
                    let anchorRect = CGRect(
                        x: item.anchor.x - radius,
                        y: item.anchor.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(
                        Path(ellipseIn: anchorRect),
                        with: .color(isAnchorSelected ? Color.white : Color(nsColor: ImageEditorTheme.selected))
                    )
                    context.stroke(Path(ellipseIn: anchorRect), with: .color(Color.black.opacity(0.55)), lineWidth: 1)
                }
            }
            .allowsHitTesting(false)
        }

        if let dragStart, let dragEnd, viewModel.selectedTool == .gradient {
            let start = viewPoint(from: dragStart, in: size)
            let end = viewPoint(from: dragEnd, in: size)
            Canvas { context, _ in
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(Color.white.opacity(0.86)), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                context.stroke(path, with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.9)), style: StrokeStyle(lineWidth: 2, dash: [7, 5], dashPhase: 6))
                context.fill(Path(ellipseIn: CGRect(x: start.x - 4, y: start.y - 4, width: 8, height: 8)), with: .color(Color.white.opacity(0.92)))
                context.fill(Path(ellipseIn: CGRect(x: end.x - 4, y: end.y - 4, width: 8, height: 8)), with: .color(Color(nsColor: ImageEditorTheme.selected).opacity(0.92)))
            }
            .allowsHitTesting(false)
        }

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
                case .brush, .eraser, .cloneStamp, .dodge, .burn, .blur, .sharpen, .smudge, .healingBrush:
                    if let imagePoint {
                        dragPoints.append(imagePoint)
                    }
                case .crop, .marquee, .rectangle, .ellipse, .gradient:
                    if dragStart == nil {
                        dragStart = imagePoint
                    }
                    dragEnd = imagePoint
                case .pen:
                    guard viewModel.pendingPenPathPoints.isEmpty,
                          viewModel.canEditSelectedPathAnchors
                    else { break }
                    if isMovingPathAnchor {
                        viewModel.moveSelectedPathAnchor(to: imagePoint)
                    } else {
                        isMovingPathAnchor = viewModel.beginMovingPathAnchor(at: imagePoint)
                    }
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
                case .cloneStamp:
                    if NSEvent.modifierFlags.contains(.option), let imagePoint {
                        viewModel.setCloneSource(at: imagePoint)
                    } else {
                        viewModel.cloneStamp(points: dragPoints)
                    }
                case .dodge:
                    viewModel.toneBrush(points: dragPoints, burn: false)
                case .burn:
                    viewModel.toneBrush(points: dragPoints, burn: true)
                case .blur:
                    viewModel.blurBrush(points: dragPoints)
                case .sharpen:
                    viewModel.sharpenBrush(points: dragPoints)
                case .smudge:
                    viewModel.smudgeBrush(points: dragPoints)
                case .healingBrush:
                    viewModel.healingBrush(points: dragPoints)
                case .paintBucket:
                    viewModel.paintBucketFill(at: imagePoint)
                case .rectangle:
                    if let dragStart, let imagePoint {
                        viewModel.drawShape(from: dragStart, to: imagePoint, ellipse: false)
                    }
                case .ellipse:
                    if let dragStart, let imagePoint {
                        viewModel.drawShape(from: dragStart, to: imagePoint, ellipse: true)
                    }
                case .pen:
                    if isMovingPathAnchor {
                        viewModel.finishMovingPathAnchor()
                    } else {
                        viewModel.addPenPoint(imagePoint)
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
                    viewModel.drawGradient(from: dragStart, to: imagePoint)
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
                isMovingPathAnchor = false
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

    private func selectedPathAnchorOverlayPoints(
        in size: CGSize
    ) -> [(subpathIndex: Int, index: Int, anchor: CGPoint, inHandle: CGPoint?, outHandle: CGPoint?)]? {
        guard let layer = viewModel.document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path
        else { return nil }
        return content.allEditablePathSubpaths.enumerated().flatMap { subpathIndex, anchors in
            anchors.enumerated().map { index, anchor in
                (
                    subpathIndex: subpathIndex,
                    index: index,
                    anchor: viewPoint(from: canvasPoint(anchor.point, layer: layer), in: size),
                    inHandle: anchor.inControl.map { viewPoint(from: canvasPoint($0, layer: layer), in: size) },
                    outHandle: anchor.outControl.map { viewPoint(from: canvasPoint($0, layer: layer), in: size) }
                )
            }
        }
    }

    private func canvasPoint(_ localPoint: CGPoint, layer: ImageEditorLayer) -> CGPoint {
        CGPoint(x: layer.frame.minX + localPoint.x, y: layer.frame.minY + localPoint.y)
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
                Image(nsImage: viewModel.previewImage)
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
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Label(viewModel.historyStateSummary, systemImage: "clock")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        .lineLimit(1)
                    Spacer()
                    Button {
                        viewModel.createHistorySnapshot()
                    } label: {
                        Image(systemName: "camera.badge.clock")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(EditorIconButtonStyle(isSelected: false))
                    .help(L10n.text("imageEditor.action.historySnapshotCreate"))
                    Button {
                        viewModel.clearHistoryStates()
                    } label: {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(EditorIconButtonStyle(isSelected: false))
                    .disabled(viewModel.document.history.count <= 1 && !viewModel.canUndo && !viewModel.canRedo)
                    .help(L10n.text("imageEditor.action.historyClear"))
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if !viewModel.namedHistorySnapshots.isEmpty {
                            Text(L10n.text("imageEditor.history.snapshots"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                .padding(.horizontal, 4)

                            ForEach(viewModel.namedHistorySnapshots) { snapshot in
                                historySnapshotRow(snapshot)
                            }

                            Divider().overlay(editorBorder)
                                .padding(.vertical, 2)
                        }

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
        }
        .frame(height: 164)
    }

    private func historySnapshotRow(_ snapshot: ImageEditorHistorySnapshot) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "camera.filters")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.selected))
                .frame(width: 16)

            TextField(
                L10n.text("imageEditor.history.snapshotNamePlaceholder"),
                text: historySnapshotNameBinding(snapshot)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
            .onSubmit {
                commitHistorySnapshotNameDraft(snapshot)
            }
            .onAppear {
                syncHistorySnapshotNameDraft(snapshot)
            }
            .onChange(of: snapshot.name) { _, _ in
                syncHistorySnapshotNameDraft(snapshot)
            }

            Button {
                viewModel.restoreHistorySnapshot(snapshot.id)
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.historySnapshotRestore", snapshot.name))

            Button {
                viewModel.deleteHistorySnapshot(snapshot.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(EditorIconButtonStyle(isSelected: false))
            .help(L10n.format("imageEditor.action.historySnapshotDelete", snapshot.name))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func historyIconName(for entry: ImageEditorHistoryEntry) -> String {
        viewModel.document.history.last?.id == entry.id ? "checkmark.circle.fill" : "clock.arrow.circlepath"
    }

    private func historyRowBackground(for entry: ImageEditorHistoryEntry) -> Color {
        viewModel.document.history.last?.id == entry.id
            ? Color(nsColor: ImageEditorTheme.selected).opacity(0.32)
            : Color.white.opacity(0.04)
    }

    private func historySnapshotNameBinding(_ snapshot: ImageEditorHistorySnapshot) -> Binding<String> {
        Binding {
            historySnapshotNameDrafts[snapshot.id] ?? snapshot.name
        } set: { value in
            historySnapshotNameDrafts[snapshot.id] = value
        }
    }

    private func syncHistorySnapshotNameDraft(_ snapshot: ImageEditorHistorySnapshot) {
        historySnapshotNameDrafts[snapshot.id] = snapshot.name
    }

    private func commitHistorySnapshotNameDraft(_ snapshot: ImageEditorHistorySnapshot) {
        viewModel.renameHistorySnapshot(snapshot.id, to: historySnapshotNameDrafts[snapshot.id] ?? snapshot.name)
        if let updatedSnapshot = viewModel.namedHistorySnapshots.first(where: { $0.id == snapshot.id }) {
            syncHistorySnapshotNameDraft(updatedSnapshot)
        }
    }

    private func syncLayerNameDraft() {
        layerNameDraft = viewModel.selectedLayerName
    }

    private var documentSizeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("imageEditor.properties.documentSize"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

            Stepper(
                L10n.format("imageEditor.properties.imageWidthValue", Int(viewModel.targetImageWidth.rounded())),
                value: $viewModel.targetImageWidth,
                in: 8...12_000,
                step: 1
            )
            Stepper(
                L10n.format("imageEditor.properties.imageHeightValue", Int(viewModel.targetImageHeight.rounded())),
                value: $viewModel.targetImageHeight,
                in: 8...12_000,
                step: 1
            )
            Button(L10n.text("imageEditor.action.imageResize")) {
                viewModel.resizeImageToControlSize()
            }
            .buttonStyle(EditorTextButtonStyle())

            Picker(L10n.text("imageEditor.properties.canvasAnchor"), selection: $viewModel.selectedCanvasAnchor) {
                ForEach(ImageEditorCanvasAnchor.allCases) { anchor in
                    Text(anchor.title).tag(anchor)
                }
            }
            .pickerStyle(.menu)

            Stepper(
                L10n.format("imageEditor.properties.canvasWidthValue", Int(viewModel.targetCanvasWidth.rounded())),
                value: $viewModel.targetCanvasWidth,
                in: 8...12_000,
                step: 1
            )
            Stepper(
                L10n.format("imageEditor.properties.canvasHeightValue", Int(viewModel.targetCanvasHeight.rounded())),
                value: $viewModel.targetCanvasHeight,
                in: 8...12_000,
                step: 1
            )
            Button(L10n.text("imageEditor.action.canvasResize")) {
                viewModel.resizeCanvasToControlSize()
            }
            .buttonStyle(EditorTextButtonStyle())

            Divider()
                .overlay(Color.white.opacity(0.12))

            guideControls
        }
    }

    private var guideControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("imageEditor.properties.guides"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

            Toggle(
                L10n.text("imageEditor.action.rulersVisible"),
                isOn: Binding(
                    get: { viewModel.document.areRulersVisible },
                    set: { _ in viewModel.toggleRulersVisible() }
                )
            )
            .toggleStyle(.checkbox)

            Toggle(
                L10n.text("imageEditor.action.guidesVisible"),
                isOn: Binding(
                    get: { viewModel.document.areGuidesVisible },
                    set: { _ in viewModel.toggleGuidesVisible() }
                )
            )
            .toggleStyle(.checkbox)

            Toggle(
                L10n.text("imageEditor.action.guidesSnap"),
                isOn: Binding(
                    get: { viewModel.document.isGuideSnappingEnabled },
                    set: { _ in viewModel.toggleGuideSnapping() }
                )
            )
            .toggleStyle(.checkbox)

            HStack(spacing: 6) {
                Button(L10n.text("imageEditor.action.guideVerticalCenter")) {
                    viewModel.addVerticalGuideAtCanvasCenter()
                }
                .buttonStyle(EditorTextButtonStyle())

                Button(L10n.text("imageEditor.action.guideHorizontalCenter")) {
                    viewModel.addHorizontalGuideAtCanvasCenter()
                }
                .buttonStyle(EditorTextButtonStyle())
            }

            HStack(spacing: 6) {
                Text(viewModel.guideSummary)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                Spacer()

                Button(L10n.text("imageEditor.action.guidesClear")) {
                    viewModel.clearGuides()
                }
                .buttonStyle(EditorTextButtonStyle())
                .disabled(viewModel.document.guides.isEmpty)
            }
        }
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

    private var selectedLayerStrokePositionBinding: Binding<ImageEditorStrokePosition> {
        Binding {
            viewModel.selectedLayerStrokePosition
        } set: { value in
            viewModel.setSelectedLayerStrokePosition(value)
        }
    }

    private var selectedLayerStrokeOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerStrokeOpacity
        } set: { value in
            viewModel.setSelectedLayerStrokeOpacity(value)
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

    private var selectedLayerShadowSpreadBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerShadowSpread
        } set: { value in
            viewModel.setSelectedLayerShadowSpread(value)
        }
    }

    private var globalLightAngleBinding: Binding<Double> {
        Binding {
            viewModel.globalLightAngle
        } set: { value in
            viewModel.setGlobalLightAngle(value)
        }
    }

    private var selectedLayerShadowUsesGlobalLightBinding: Binding<Bool> {
        Binding {
            viewModel.selectedLayerShadowUsesGlobalLight
        } set: { value in
            viewModel.setSelectedLayerShadowUsesGlobalLight(value)
        }
    }

    private var selectedLayerShadowDistanceBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerShadowDistance
        } set: { value in
            viewModel.setSelectedLayerShadowDistance(value)
        }
    }

    private var selectedLayerShadowAngleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerShadowAngle
        } set: { value in
            viewModel.setSelectedLayerShadowAngle(value)
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

    private var selectedLayerInnerShadowOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerShadowOpacity
        } set: { value in
            viewModel.setSelectedLayerInnerShadowOpacity(value)
        }
    }

    private var selectedLayerInnerShadowBlurBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerShadowBlur
        } set: { value in
            viewModel.setSelectedLayerInnerShadowBlur(value)
        }
    }

    private var selectedLayerInnerShadowDistanceBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerShadowDistance
        } set: { value in
            viewModel.setSelectedLayerInnerShadowDistance(value)
        }
    }

    private var selectedLayerInnerShadowAngleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerShadowAngle
        } set: { value in
            viewModel.setSelectedLayerInnerShadowAngle(value)
        }
    }

    private var selectedLayerInnerShadowUsesGlobalLightBinding: Binding<Bool> {
        Binding {
            viewModel.selectedLayerInnerShadowUsesGlobalLight
        } set: { value in
            viewModel.setSelectedLayerInnerShadowUsesGlobalLight(value)
        }
    }

    private var selectedLayerOuterGlowOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerOuterGlowOpacity
        } set: { value in
            viewModel.setSelectedLayerOuterGlowOpacity(value)
        }
    }

    private var selectedLayerOuterGlowBlurBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerOuterGlowBlur
        } set: { value in
            viewModel.setSelectedLayerOuterGlowBlur(value)
        }
    }

    private var selectedLayerOuterGlowSpreadBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerOuterGlowSpread
        } set: { value in
            viewModel.setSelectedLayerOuterGlowSpread(value)
        }
    }

    private var selectedLayerInnerGlowOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerGlowOpacity
        } set: { value in
            viewModel.setSelectedLayerInnerGlowOpacity(value)
        }
    }

    private var selectedLayerInnerGlowBlurBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerGlowBlur
        } set: { value in
            viewModel.setSelectedLayerInnerGlowBlur(value)
        }
    }

    private var selectedLayerInnerGlowChokeBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerInnerGlowChoke
        } set: { value in
            viewModel.setSelectedLayerInnerGlowChoke(value)
        }
    }

    private var selectedLayerColorOverlayOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerColorOverlayOpacity
        } set: { value in
            viewModel.setSelectedLayerColorOverlayOpacity(value)
        }
    }

    private var selectedLayerGradientOverlayOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerGradientOverlayOpacity
        } set: { value in
            viewModel.setSelectedLayerGradientOverlayOpacity(value)
        }
    }

    private var selectedLayerGradientOverlayAngleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerGradientOverlayAngle
        } set: { value in
            viewModel.setSelectedLayerGradientOverlayAngle(value)
        }
    }

    private var selectedLayerPatternOverlayKindBinding: Binding<ImageEditorPatternOverlayKind> {
        Binding {
            viewModel.selectedLayerPatternOverlayKind
        } set: { value in
            viewModel.setSelectedLayerPatternOverlayKind(value)
        }
    }

    private var selectedLayerPatternOverlayOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerPatternOverlayOpacity
        } set: { value in
            viewModel.setSelectedLayerPatternOverlayOpacity(value)
        }
    }

    private var selectedLayerPatternOverlayScaleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerPatternOverlayScale
        } set: { value in
            viewModel.setSelectedLayerPatternOverlayScale(value)
        }
    }

    private var selectedLayerSatinOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerSatinOpacity
        } set: { value in
            viewModel.setSelectedLayerSatinOpacity(value)
        }
    }

    private var selectedLayerSatinDistanceBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerSatinDistance
        } set: { value in
            viewModel.setSelectedLayerSatinDistance(value)
        }
    }

    private var selectedLayerSatinSizeBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerSatinSize
        } set: { value in
            viewModel.setSelectedLayerSatinSize(value)
        }
    }

    private var selectedLayerSatinAngleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerSatinAngle
        } set: { value in
            viewModel.setSelectedLayerSatinAngle(value)
        }
    }

    private var selectedLayerBevelSizeBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerBevelSize
        } set: { value in
            viewModel.setSelectedLayerBevelSize(value)
        }
    }

    private var selectedLayerBevelOpacityBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerBevelOpacity
        } set: { value in
            viewModel.setSelectedLayerBevelOpacity(value)
        }
    }

    private var selectedLayerBevelAngleBinding: Binding<Double> {
        Binding {
            viewModel.selectedLayerBevelAngle
        } set: { value in
            viewModel.setSelectedLayerBevelAngle(value)
        }
    }

    private var selectedLayerBevelUsesGlobalLightBinding: Binding<Bool> {
        Binding {
            viewModel.selectedLayerBevelUsesGlobalLight
        } set: { value in
            viewModel.setSelectedLayerBevelUsesGlobalLight(value)
        }
    }

    private func guidePath(orientation: ImageEditorGuideOrientation, position: CGFloat, in size: CGSize) -> Path {
        var path = Path()
        switch orientation {
        case .vertical:
            let start = viewPoint(from: CGPoint(x: position, y: 0), in: size)
            let end = viewPoint(from: CGPoint(x: position, y: viewModel.document.canvasSize.height), in: size)
            path.move(to: start)
            path.addLine(to: end)
        case .horizontal:
            let start = viewPoint(from: CGPoint(x: 0, y: position), in: size)
            let end = viewPoint(from: CGPoint(x: viewModel.document.canvasSize.width, y: position), in: size)
            path.move(to: start)
            path.addLine(to: end)
        }
        return path
    }

    @ViewBuilder
    private func gridOverlay(in size: CGSize) -> some View {
        if viewModel.document.isGridVisible {
            Canvas { context, _ in
                let canvasSize = viewModel.document.canvasSize
                let spacing = max(4, min(512, viewModel.document.gridSpacing))
                let verticalCount = Int((canvasSize.width / spacing).rounded(.up))
                let horizontalCount = Int((canvasSize.height / spacing).rounded(.up))

                for index in 0...verticalCount {
                    let position = min(canvasSize.width, CGFloat(index) * spacing)
                    let opacity = index.isMultiple(of: 4) ? 0.34 : 0.18
                    context.stroke(
                        guidePath(orientation: .vertical, position: position, in: size),
                        with: .color(.white.opacity(opacity)),
                        lineWidth: index.isMultiple(of: 4) ? 0.85 : 0.55
                    )
                }

                for index in 0...horizontalCount {
                    let position = min(canvasSize.height, CGFloat(index) * spacing)
                    let opacity = index.isMultiple(of: 4) ? 0.34 : 0.18
                    context.stroke(
                        guidePath(orientation: .horizontal, position: position, in: size),
                        with: .color(.white.opacity(opacity)),
                        lineWidth: index.isMultiple(of: 4) ? 0.85 : 0.55
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func guideOverlay(in size: CGSize) -> some View {
        Canvas { context, _ in
            if viewModel.document.areGuidesVisible {
                for guide in viewModel.document.guides {
                    context.stroke(
                        guidePath(orientation: guide.orientation, position: guide.position, in: size),
                        with: .color(.cyan.opacity(0.82)),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
                }
            }

            if let activeGuideDrag {
                context.stroke(
                    guidePath(
                        orientation: activeGuideDrag.orientation,
                        position: activeGuideDrag.position,
                        in: size
                    ),
                    with: .color(.yellow.opacity(0.9)),
                    style: StrokeStyle(lineWidth: 1.4, dash: [3, 3])
                )
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func guideInteractionOverlay(in size: CGSize) -> some View {
        if viewModel.document.areGuidesVisible {
            let rect = fittedImageRect(in: size)
            ZStack {
                ForEach(viewModel.document.guides) { guide in
                    let anchor = guideAnchorPoint(guide, in: size)
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(
                            width: guide.orientation == .vertical ? 12 : max(rect.width, 1),
                            height: guide.orientation == .vertical ? max(rect.height, 1) : 12
                        )
                        .position(anchor)
                        .highPriorityGesture(existingGuideGesture(guide, in: size))
                }
            }
        }
    }

    @ViewBuilder
    private func rulerOverlay(in size: CGSize) -> some View {
        if viewModel.document.areRulersVisible {
            let rect = fittedImageRect(in: size)
            let thickness: CGFloat = 22
            ZStack {
                Canvas { context, _ in
                    drawRulers(context: context, imageRect: rect, thickness: thickness, canvasSize: size)
                }
                .allowsHitTesting(false)

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: max(rect.width, 1), height: thickness)
                    .position(x: rect.midX, y: rect.minY - thickness / 2)
                    .highPriorityGesture(rulerGuideGesture(.vertical, in: size))

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: thickness, height: max(rect.height, 1))
                    .position(x: rect.minX - thickness / 2, y: rect.midY)
                    .highPriorityGesture(rulerGuideGesture(.horizontal, in: size))
            }
        }
    }

    private func guideAnchorPoint(_ guide: ImageEditorGuide, in size: CGSize) -> CGPoint {
        switch guide.orientation {
        case .vertical:
            return viewPoint(from: CGPoint(x: guide.position, y: viewModel.document.canvasSize.height / 2), in: size)
        case .horizontal:
            return viewPoint(from: CGPoint(x: viewModel.document.canvasSize.width / 2, y: guide.position), in: size)
        }
    }

    private func guidePosition(from location: CGPoint, orientation: ImageEditorGuideOrientation, in size: CGSize) -> CGFloat {
        let point = unboundedImagePoint(from: location, in: size)
        let upperBound: CGFloat
        let rawPosition: CGFloat
        switch orientation {
        case .vertical:
            upperBound = viewModel.document.canvasSize.width
            rawPosition = point.x
        case .horizontal:
            upperBound = viewModel.document.canvasSize.height
            rawPosition = point.y
        }
        return min(max(0, rawPosition.rounded()), max(0, upperBound.rounded()))
    }

    private func existingGuideGesture(_ guide: ImageEditorGuide, in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let position = guidePosition(from: value.location, orientation: guide.orientation, in: size)
                if activeGuideDrag == nil {
                    viewModel.beginMovingGuide(guide.id)
                }
                activeGuideDrag = ImageEditorGuideDrag(orientation: guide.orientation, position: position)
                viewModel.moveGuide(guide.id, to: position)
            }
            .onEnded { _ in
                viewModel.finishMovingGuide()
                activeGuideDrag = nil
            }
    }

    private func rulerGuideGesture(_ orientation: ImageEditorGuideOrientation, in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                activeGuideDrag = ImageEditorGuideDrag(
                    orientation: orientation,
                    position: guidePosition(from: value.location, orientation: orientation, in: size)
                )
            }
            .onEnded { value in
                if fittedImageRect(in: size).contains(value.location) {
                    viewModel.addGuide(
                        orientation,
                        at: guidePosition(from: value.location, orientation: orientation, in: size)
                    )
                }
                activeGuideDrag = nil
            }
    }

    private func drawRulers(context: GraphicsContext, imageRect: CGRect, thickness: CGFloat, canvasSize: CGSize) {
        guard imageRect.width > 0, imageRect.height > 0 else { return }
        let topRect = CGRect(x: imageRect.minX, y: imageRect.minY - thickness, width: imageRect.width, height: thickness)
        let leftRect = CGRect(x: imageRect.minX - thickness, y: imageRect.minY, width: thickness, height: imageRect.height)
        let cornerRect = CGRect(x: imageRect.minX - thickness, y: imageRect.minY - thickness, width: thickness, height: thickness)
        let background = Color(nsColor: ImageEditorTheme.panelRaised).opacity(0.94)
        let strokeColor = Color.white.opacity(0.24)
        let tickColor = Color.white.opacity(0.58)
        let labelColor = Color(nsColor: ImageEditorTheme.mutedText)

        context.fill(Path(topRect), with: .color(background))
        context.fill(Path(leftRect), with: .color(background))
        context.fill(Path(cornerRect), with: .color(background.opacity(0.9)))
        context.stroke(Path(topRect), with: .color(strokeColor), lineWidth: 1)
        context.stroke(Path(leftRect), with: .color(strokeColor), lineWidth: 1)

        let xScale = imageRect.width / max(viewModel.document.canvasSize.width, 1)
        let yScale = imageRect.height / max(viewModel.document.canvasSize.height, 1)
        let xStep = rulerStep(pixelScale: xScale)
        let yStep = rulerStep(pixelScale: yScale)

        var xPosition: CGFloat = 0
        while xPosition <= viewModel.document.canvasSize.width + 0.5 {
            let viewX = viewPoint(from: CGPoint(x: xPosition, y: 0), in: canvasSize).x
            var tick = Path()
            tick.move(to: CGPoint(x: viewX, y: topRect.maxY))
            tick.addLine(to: CGPoint(x: viewX, y: topRect.maxY - 8))
            context.stroke(tick, with: .color(tickColor), lineWidth: 1)
            context.draw(
                Text("\(Int(xPosition.rounded()))")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(labelColor),
                at: CGPoint(x: viewX + 3, y: topRect.midY - 2),
                anchor: .leading
            )
            xPosition += xStep
        }

        var yPosition: CGFloat = 0
        while yPosition <= viewModel.document.canvasSize.height + 0.5 {
            let viewY = viewPoint(from: CGPoint(x: 0, y: yPosition), in: canvasSize).y
            var tick = Path()
            tick.move(to: CGPoint(x: leftRect.maxX, y: viewY))
            tick.addLine(to: CGPoint(x: leftRect.maxX - 8, y: viewY))
            context.stroke(tick, with: .color(tickColor), lineWidth: 1)
            context.draw(
                Text("\(Int(yPosition.rounded()))")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(labelColor),
                at: CGPoint(x: leftRect.minX + 3, y: viewY - 2),
                anchor: .leading
            )
            yPosition += yStep
        }
    }

    private func rulerStep(pixelScale: CGFloat) -> CGFloat {
        for step in [10, 25, 50, 100, 250, 500, 1_000, 2_000] where CGFloat(step) * pixelScale >= 48 {
            return CGFloat(step)
        }
        return 5_000
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

                documentSizeControls

                Divider().overlay(editorBorder)

                Picker(L10n.text("imageEditor.properties.adjustment"), selection: $viewModel.selectedAdjustment) {
                    ForEach(ImageEditorAdjustment.allCases) { adjustment in
                        Text(adjustment.title).tag(adjustment)
                    }
                }
                if viewModel.selectedAdjustment == .levels {
                    levelsControls
                } else if viewModel.selectedAdjustment == .curves {
                    curvesControls
                } else if viewModel.selectedAdjustment == .colorBalance {
                    colorBalanceControls
                } else if viewModel.selectedAdjustment == .hueSaturation {
                    hueSaturationControls
                } else if viewModel.selectedAdjustment == .brightnessContrast {
                    brightnessContrastControls
                } else if viewModel.selectedAdjustment == .exposure {
                    exposureControls
                } else if viewModel.selectedAdjustment == .shadowsHighlights {
                    shadowsHighlightsControls
                } else if viewModel.selectedAdjustment == .posterize {
                    posterizeControls
                } else if viewModel.selectedAdjustment == .blackWhite {
                    blackWhiteControls
                } else if viewModel.selectedAdjustment == .channelMixer {
                    channelMixerControls
                } else if viewModel.selectedAdjustment == .photoFilter {
                    photoFilterControls
                } else if viewModel.selectedAdjustment == .colorLookup {
                    colorLookupControls
                } else if viewModel.selectedAdjustment == .selectiveColor {
                    selectiveColorControls
                } else if viewModel.selectedAdjustment == .gradientMap {
                    gradientMapControls
                } else {
                    Slider(value: $viewModel.adjustmentValue, in: -1...1, step: 0.05)
                }
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
                        Button(L10n.text("imageEditor.action.selectAll")) {
                            viewModel.selectAll()
                        }
                        .buttonStyle(EditorTextButtonStyle())
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
                    if viewModel.hasSelection {
                        HStack(spacing: 8) {
                            Text(L10n.text("imageEditor.option.selectionModifyAmount"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            Slider(value: $viewModel.selectionModifyAmount, in: 1...64, step: 1)
                            Text("\(Int(viewModel.selectionModifyAmount.rounded()))px")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                                .frame(width: 36, alignment: .trailing)
                        }
                        HStack {
                            Button(L10n.text("imageEditor.action.expandSelection")) {
                                viewModel.expandSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            Button(L10n.text("imageEditor.action.contractSelection")) {
                                viewModel.contractSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            Button(L10n.text("imageEditor.action.featherSelection")) {
                                viewModel.featherSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            Button(L10n.text("imageEditor.action.borderSelection")) {
                                viewModel.borderSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            Button(L10n.text("imageEditor.action.smoothSelection")) {
                                viewModel.smoothSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                        }
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
                if viewModel.selectedFilter == .unsharpMask {
                    HStack {
                        Text(L10n.text("imageEditor.filter.unsharpRadius"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterUnsharpRadius, in: 0.5...5, step: 0.5)
                        Text(L10n.format("imageEditor.filter.unsharpRadiusValue", String(format: "%.1f", viewModel.filterUnsharpRadius)))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                    HStack {
                        Text(L10n.text("imageEditor.filter.unsharpThreshold"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        Slider(value: $viewModel.filterUnsharpThreshold, in: 0...1, step: 0.05)
                        Text(L10n.format("imageEditor.filter.unsharpThresholdValue", Int((viewModel.filterUnsharpThreshold * 255).rounded())))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Text(viewModel.selectedLayerSmartFilterText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .lineLimit(2)
                if viewModel.selectedLayerHasSmartFilters {
                    VStack(spacing: 6) {
                        ForEach(viewModel.selectedLayerSmartFilters) { filter in
                            HStack(spacing: 6) {
                                Text(viewModel.smartFilterLabel(filter))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(filter.isEnabled ? Color(nsColor: ImageEditorTheme.text) : Color(nsColor: ImageEditorTheme.mutedText))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button(L10n.text(filter.isEnabled ? "imageEditor.action.layerSmartFilterDisable" : "imageEditor.action.layerSmartFilterEnable")) {
                                    viewModel.toggleSmartFilterOnSelectedLayer(filter.id)
                                }
                                .buttonStyle(EditorTextButtonStyle())
                                Button(L10n.text("imageEditor.action.layerSmartFilterUpdateShort")) {
                                    viewModel.updateSmartFilterOnSelectedLayer(filter.id)
                                }
                                .buttonStyle(EditorTextButtonStyle())
                                Button(L10n.text("imageEditor.action.layerSmartFilterMoveUp")) {
                                    viewModel.moveSmartFilterOnSelectedLayer(filter.id, offset: -1)
                                }
                                .buttonStyle(EditorTextButtonStyle())
                                Button(L10n.text("imageEditor.action.layerSmartFilterMoveDown")) {
                                    viewModel.moveSmartFilterOnSelectedLayer(filter.id, offset: 1)
                                }
                                .buttonStyle(EditorTextButtonStyle())
                                Button(L10n.text("imageEditor.action.layerSmartFilterRemove")) {
                                    viewModel.removeSmartFilterFromSelectedLayer(filter.id)
                                }
                                .buttonStyle(EditorTextButtonStyle())
                            }
                        }
                    }
                }
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
                HStack {
                    Button(L10n.text("imageEditor.action.layerSmartFilterAdd")) {
                        viewModel.addSmartFilterToSelectedLayer()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                    .disabled(!viewModel.canAddSmartFilterToSelectedLayer)
                    if viewModel.selectedLayerHasSmartFilters {
                        Button(L10n.text("imageEditor.action.layerSmartFilterUpdate")) {
                            viewModel.updateLastSmartFilterOnSelectedLayer()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        Button(L10n.text("imageEditor.action.layerSmartFilterClear")) {
                            viewModel.clearSmartFiltersFromSelectedLayer()
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
                Picker(L10n.text("imageEditor.properties.textAlignment"), selection: $viewModel.selectedTextAlignment) {
                    ForEach(ImageEditorTextAlignment.allCases) { alignment in
                        Text(alignment.title).tag(alignment)
                    }
                }
                .pickerStyle(.segmented)
                HStack {
                    Toggle(L10n.text("imageEditor.properties.textBold"), isOn: $viewModel.textBold)
                        .toggleStyle(.checkbox)
                    Toggle(L10n.text("imageEditor.properties.textItalic"), isOn: $viewModel.textItalic)
                        .toggleStyle(.checkbox)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.textCharacterSpacingValue", Int(viewModel.textCharacterSpacing.rounded())),
                        value: $viewModel.textCharacterSpacing,
                        in: -8...48,
                        step: 1
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.textLineSpacingValue", Int(viewModel.textLineSpacing.rounded())),
                        value: $viewModel.textLineSpacing,
                        in: 0...96,
                        step: 1
                    )
                }
                Stepper(
                    L10n.format("imageEditor.properties.textBoxWidthValue", Int(viewModel.textBoxWidth.rounded())),
                    value: $viewModel.textBoxWidth,
                    in: 0...1600,
                    step: 8
                )
                if viewModel.canEditSelectedPathAnchors {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.text("imageEditor.properties.pathAnchors"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                        HStack {
                            Button(L10n.text("imageEditor.action.pathAnchorPrevious")) {
                                viewModel.selectPreviousPathAnchor()
                            }
                            .buttonStyle(EditorTextButtonStyle())

                            Button(L10n.text("imageEditor.action.pathAnchorNext")) {
                                viewModel.selectNextPathAnchor()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                        }
                        HStack {
                            Button(L10n.text("imageEditor.action.pathAnchorSmooth")) {
                                viewModel.smoothSelectedPathAnchor()
                            }
                            .buttonStyle(EditorTextButtonStyle())

                            Button(L10n.text("imageEditor.action.pathAnchorClearHandles")) {
                                viewModel.clearSelectedPathAnchorHandles()
                            }
                            .buttonStyle(EditorTextButtonStyle())

                            Button(L10n.text("imageEditor.action.pathAnchorSymmetric")) {
                                viewModel.symmetrizeSelectedPathAnchorHandles()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canSymmetrizeSelectedPathAnchorHandles)
                        }
                        HStack {
                            Button(L10n.text("imageEditor.action.pathAnchorInsert")) {
                                viewModel.insertPathAnchorAfterSelection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canInsertPathAnchorAfterSelection)

                            Button(L10n.text("imageEditor.action.pathAnchorDelete")) {
                                viewModel.deleteSelectedPathAnchor()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canDeleteSelectedPathAnchor)

                            Button(L10n.text(viewModel.selectedPathIsClosed ? "imageEditor.action.pathOpen" : "imageEditor.action.pathClose")) {
                                viewModel.toggleSelectedPathClosed()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canToggleSelectedPathClosed)
                        }
                        HStack {
                            Button(L10n.text("imageEditor.action.pathSubpathPrevious")) {
                                viewModel.selectPreviousPathSubpath()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canSelectAdjacentPathSubpath)

                            Button(L10n.text("imageEditor.action.pathSubpathNext")) {
                                viewModel.selectNextPathSubpath()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canSelectAdjacentPathSubpath)
                        }
                        HStack {
                            Button(L10n.text("imageEditor.action.pathSubpathDuplicate")) {
                                viewModel.duplicateSelectedPathSubpath()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canDuplicateSelectedPathSubpath)

                            Button(L10n.text("imageEditor.action.pathReverse")) {
                                viewModel.reverseSelectedPathDirection()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canReverseSelectedPathDirection)

                            Button(L10n.text("imageEditor.action.pathSubpathDelete")) {
                                viewModel.deleteSelectedPathSubpath()
                            }
                            .buttonStyle(EditorTextButtonStyle())
                            .disabled(!viewModel.canDeleteSelectedPathSubpath)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.text("imageEditor.properties.pathSubpathNudge"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                            HStack {
                                Button(L10n.text("imageEditor.action.pathSubpathNudgeLeft")) {
                                    viewModel.nudgeSelectedPathSubpath(dx: -1, dy: 0)
                                }
                                .buttonStyle(EditorTextButtonStyle())
                                .disabled(!viewModel.canMoveSelectedPathSubpath)

                                Button(L10n.text("imageEditor.action.pathSubpathNudgeRight")) {
                                    viewModel.nudgeSelectedPathSubpath(dx: 1, dy: 0)
                                }
                                .buttonStyle(EditorTextButtonStyle())
                                .disabled(!viewModel.canMoveSelectedPathSubpath)
                            }
                            HStack {
                                Button(L10n.text("imageEditor.action.pathSubpathNudgeUp")) {
                                    viewModel.nudgeSelectedPathSubpath(dx: 0, dy: -1)
                                }
                                .buttonStyle(EditorTextButtonStyle())
                                .disabled(!viewModel.canMoveSelectedPathSubpath)

                                Button(L10n.text("imageEditor.action.pathSubpathNudgeDown")) {
                                    viewModel.nudgeSelectedPathSubpath(dx: 0, dy: 1)
                                }
                                .buttonStyle(EditorTextButtonStyle())
                                .disabled(!viewModel.canMoveSelectedPathSubpath)
                            }
                        }
                        Button(L10n.text("imageEditor.action.pathStroke")) {
                            viewModel.strokeSelectedPathToPixelLayer()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.canStrokeSelectedPathToPixelLayer)
                        Button(L10n.text("imageEditor.action.pathFill")) {
                            viewModel.fillSelectedPathToPixelLayer()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.canFillSelectedPathToPixelLayer)
                        Button(L10n.text("imageEditor.action.pathSelection")) {
                            viewModel.loadSelectionFromSelectedPath()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.canLoadSelectionFromSelectedPath)
                        Button(L10n.text("imageEditor.action.pathVectorMask")) {
                            viewModel.applySelectedPathAsVectorMask()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.canApplySelectedPathAsVectorMask)
                        Button(L10n.text("imageEditor.action.pathLayerMask")) {
                            viewModel.applySelectedPathAsLayerMask()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.canApplySelectedPathAsLayerMask)
                        if let point = viewModel.selectedPathAnchorCanvasPoint {
                            HStack {
                                Stepper(
                                    L10n.format("imageEditor.properties.pathAnchorXValue", Int(point.x.rounded())),
                                    value: Binding(
                                        get: { viewModel.selectedPathAnchorCanvasPoint?.x ?? 0 },
                                        set: { viewModel.setSelectedPathAnchorX($0) }
                                    ),
                                    in: 0...viewModel.document.canvasSize.width,
                                    step: 1
                                )
                                Stepper(
                                    L10n.format("imageEditor.properties.pathAnchorYValue", Int(point.y.rounded())),
                                    value: Binding(
                                        get: { viewModel.selectedPathAnchorCanvasPoint?.y ?? 0 },
                                        set: { viewModel.setSelectedPathAnchorY($0) }
                                    ),
                                    in: 0...viewModel.document.canvasSize.height,
                                    step: 1
                                )
                            }
                        }
                    }
                }
                if viewModel.selectedTool == .pen || !viewModel.pendingPenPathPoints.isEmpty {
                    HStack {
                        Button(L10n.text("imageEditor.action.penFinishOpen")) {
                            viewModel.finishPenPath(closed: false)
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(!viewModel.canFinishPenPath)

                        Button(L10n.text("imageEditor.action.penFinishClosed")) {
                            viewModel.finishPenPath(closed: true)
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(viewModel.pendingPenPathPoints.count < 3)

                        Button(L10n.text("imageEditor.action.penCancel")) {
                            viewModel.cancelPenPath()
                        }
                        .buttonStyle(EditorTextButtonStyle())
                        .disabled(viewModel.pendingPenPathPoints.isEmpty)
                    }
                }
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
                    if viewModel.selectedLayerIsShape {
                        Button(L10n.text("imageEditor.action.layerShapeUpdate")) {
                            viewModel.updateSelectedShapeLayer()
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
                Picker(L10n.text("imageEditor.properties.strokePosition"), selection: selectedLayerStrokePositionBinding) {
                    ForEach(ImageEditorStrokePosition.allCases) { position in
                        Text(position.title).tag(position)
                    }
                }
                .pickerStyle(.menu)
                Stepper(
                    L10n.format("imageEditor.properties.strokeOpacityValue", Int((viewModel.selectedLayerStrokeOpacity * 100).rounded())),
                    value: selectedLayerStrokeOpacityBinding,
                    in: 0.05...1,
                    step: 0.05
                )
                HStack(spacing: 8) {
                    Text(L10n.text("imageEditor.properties.strokeColor"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: viewModel.selectedLayerStrokeColor))
                        .frame(width: 20, height: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(nsColor: ImageEditorTheme.border), lineWidth: 1)
                        )
                    Spacer(minLength: 4)
                    Button(L10n.text("imageEditor.action.strokeColorFromForeground")) {
                        viewModel.setSelectedLayerStrokeColorFromForeground()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                }
                Stepper(
                    L10n.format("imageEditor.properties.shadowOpacityValue", Int((viewModel.selectedLayerShadowOpacity * 100).rounded())),
                    value: selectedLayerShadowOpacityBinding,
                    in: 0.05...1,
                    step: 0.05
                )
                HStack(spacing: 8) {
                    Text(L10n.text("imageEditor.properties.shadowColor"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: viewModel.selectedLayerShadowColor))
                        .frame(width: 20, height: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(nsColor: ImageEditorTheme.border), lineWidth: 1)
                        )
                    Spacer(minLength: 4)
                    Button(L10n.text("imageEditor.action.shadowColorFromForeground")) {
                        viewModel.setSelectedLayerShadowColorFromForeground()
                    }
                    .buttonStyle(EditorTextButtonStyle())
                }
                Stepper(
                    L10n.format("imageEditor.properties.shadowBlurValue", Int(viewModel.selectedLayerShadowBlur.rounded())),
                    value: selectedLayerShadowBlurBinding,
                    in: 0...30,
                    step: 1
                )
                Stepper(
                    L10n.format("imageEditor.properties.shadowSpreadValue", Int(viewModel.selectedLayerShadowSpread.rounded())),
                    value: selectedLayerShadowSpreadBinding,
                    in: 0...24,
                    step: 1
                )
                Toggle(L10n.text("imageEditor.properties.shadowUseGlobalLight"), isOn: selectedLayerShadowUsesGlobalLightBinding)
                    .toggleStyle(.checkbox)
                Stepper(
                    L10n.format("imageEditor.properties.globalLightAngleValue", Int(viewModel.globalLightAngle.rounded())),
                    value: globalLightAngleBinding,
                    in: -180...180,
                    step: 15
                )
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.shadowDistanceValue", Int(viewModel.selectedLayerShadowDistance.rounded())),
                        value: selectedLayerShadowDistanceBinding,
                        in: 0...80,
                        step: 1
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.shadowAngleValue", Int(viewModel.selectedLayerShadowAngle.rounded())),
                        value: selectedLayerShadowAngleBinding,
                        in: -180...180,
                        step: 15
                    )
                }
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
                Stepper(
                    L10n.format("imageEditor.properties.innerShadowOpacityValue", Int((viewModel.selectedLayerInnerShadowOpacity * 100).rounded())),
                    value: selectedLayerInnerShadowOpacityBinding,
                    in: 0.05...1,
                    step: 0.05
                )
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.innerShadowBlurValue", Int(viewModel.selectedLayerInnerShadowBlur.rounded())),
                        value: selectedLayerInnerShadowBlurBinding,
                        in: 0...40,
                        step: 1
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.innerShadowDistanceValue", Int(viewModel.selectedLayerInnerShadowDistance.rounded())),
                        value: selectedLayerInnerShadowDistanceBinding,
                        in: 0...48,
                        step: 1
                    )
                }
                Stepper(
                    L10n.format("imageEditor.properties.innerShadowAngleValue", Int(viewModel.selectedLayerInnerShadowAngle.rounded())),
                    value: selectedLayerInnerShadowAngleBinding,
                    in: -180...180,
                    step: 15
                )
                Toggle(L10n.text("imageEditor.properties.innerShadowUseGlobalLight"), isOn: selectedLayerInnerShadowUsesGlobalLightBinding)
                    .toggleStyle(.checkbox)
                Stepper(
                    L10n.format("imageEditor.properties.outerGlowOpacityValue", Int((viewModel.selectedLayerOuterGlowOpacity * 100).rounded())),
                    value: selectedLayerOuterGlowOpacityBinding,
                    in: 0.05...1,
                    step: 0.05
                )
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.outerGlowBlurValue", Int(viewModel.selectedLayerOuterGlowBlur.rounded())),
                        value: selectedLayerOuterGlowBlurBinding,
                        in: 0...40,
                        step: 1
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.outerGlowSpreadValue", Int(viewModel.selectedLayerOuterGlowSpread.rounded())),
                        value: selectedLayerOuterGlowSpreadBinding,
                        in: 0...24,
                        step: 1
                    )
                }
                Stepper(
                    L10n.format("imageEditor.properties.innerGlowOpacityValue", Int((viewModel.selectedLayerInnerGlowOpacity * 100).rounded())),
                    value: selectedLayerInnerGlowOpacityBinding,
                    in: 0.05...1,
                    step: 0.05
                )
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.innerGlowBlurValue", Int(viewModel.selectedLayerInnerGlowBlur.rounded())),
                        value: selectedLayerInnerGlowBlurBinding,
                        in: 0...40,
                        step: 1
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.innerGlowChokeValue", Int(viewModel.selectedLayerInnerGlowChoke.rounded())),
                        value: selectedLayerInnerGlowChokeBinding,
                        in: 0...24,
                        step: 1
                    )
                }
                Stepper(
                    L10n.format("imageEditor.properties.colorOverlayOpacityValue", Int((viewModel.selectedLayerColorOverlayOpacity * 100).rounded())),
                    value: selectedLayerColorOverlayOpacityBinding,
                    in: 0.05...1,
                    step: 0.05
                )
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.gradientOverlayOpacityValue", Int((viewModel.selectedLayerGradientOverlayOpacity * 100).rounded())),
                        value: selectedLayerGradientOverlayOpacityBinding,
                        in: 0.05...1,
                        step: 0.05
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.gradientOverlayAngleValue", Int(viewModel.selectedLayerGradientOverlayAngle.rounded())),
                        value: selectedLayerGradientOverlayAngleBinding,
                        in: -180...180,
                        step: 15
                    )
                }
                Picker(L10n.text("imageEditor.properties.patternOverlayKind"), selection: selectedLayerPatternOverlayKindBinding) {
                    ForEach(ImageEditorPatternOverlayKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.patternOverlayOpacityValue", Int((viewModel.selectedLayerPatternOverlayOpacity * 100).rounded())),
                        value: selectedLayerPatternOverlayOpacityBinding,
                        in: 0.05...1,
                        step: 0.05
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.patternOverlayScaleValue", Int(viewModel.selectedLayerPatternOverlayScale.rounded())),
                        value: selectedLayerPatternOverlayScaleBinding,
                        in: 6...64,
                        step: 2
                    )
                }
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.satinOpacityValue", Int((viewModel.selectedLayerSatinOpacity * 100).rounded())),
                        value: selectedLayerSatinOpacityBinding,
                        in: 0.05...1,
                        step: 0.05
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.satinDistanceValue", Int(viewModel.selectedLayerSatinDistance.rounded())),
                        value: selectedLayerSatinDistanceBinding,
                        in: 1...48,
                        step: 1
                    )
                }
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.satinSizeValue", Int(viewModel.selectedLayerSatinSize.rounded())),
                        value: selectedLayerSatinSizeBinding,
                        in: 0...40,
                        step: 1
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.satinAngleValue", Int(viewModel.selectedLayerSatinAngle.rounded())),
                        value: selectedLayerSatinAngleBinding,
                        in: -180...180,
                        step: 15
                    )
                }
                HStack {
                    Stepper(
                        L10n.format("imageEditor.properties.bevelSizeValue", Int(viewModel.selectedLayerBevelSize.rounded())),
                        value: selectedLayerBevelSizeBinding,
                        in: 1...24,
                        step: 1
                    )
                    Stepper(
                        L10n.format("imageEditor.properties.bevelOpacityValue", Int((viewModel.selectedLayerBevelOpacity * 100).rounded())),
                        value: selectedLayerBevelOpacityBinding,
                        in: 0.05...1,
                        step: 0.05
                    )
                }
                Toggle(L10n.text("imageEditor.properties.bevelUseGlobalLight"), isOn: selectedLayerBevelUsesGlobalLightBinding)
                    .toggleStyle(.checkbox)
                Stepper(
                    L10n.format("imageEditor.properties.bevelAngleValue", Int(viewModel.selectedLayerBevelAngle.rounded())),
                    value: selectedLayerBevelAngleBinding,
                    in: -180...180,
                    step: 15
                )

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

    private var levelsControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            levelsSlider(
                labelKey: "imageEditor.levels.blackPoint",
                value: $viewModel.levelsBlackPoint,
                range: 0...0.98,
                step: 0.01,
                displayText: "\(Int((viewModel.levelsBlackPoint * 255).rounded()))"
            )
            levelsSlider(
                labelKey: "imageEditor.levels.gamma",
                value: $viewModel.levelsGamma,
                range: 0.1...4,
                step: 0.05,
                displayText: String(format: "%.2f", viewModel.levelsGamma)
            )
            levelsSlider(
                labelKey: "imageEditor.levels.whitePoint",
                value: $viewModel.levelsWhitePoint,
                range: 0.02...1,
                step: 0.01,
                displayText: "\(Int((viewModel.levelsWhitePoint * 255).rounded()))"
            )
        }
    }

    private var curvesControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            adjustmentSlider(
                labelKey: "imageEditor.curves.shadows",
                value: $viewModel.curvesShadows,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.curvesShadows * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.curves.midtones",
                value: $viewModel.curvesMidtones,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.curvesMidtones * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.curves.highlights",
                value: $viewModel.curvesHighlights,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.curvesHighlights * 100).rounded()))%"
            )
        }
    }

    private var colorBalanceControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            colorBalanceSection(
                titleKey: "imageEditor.colorBalance.shadows",
                cyanRed: $viewModel.colorBalanceShadowsCyanRed,
                magentaGreen: $viewModel.colorBalanceShadowsMagentaGreen,
                yellowBlue: $viewModel.colorBalanceShadowsYellowBlue
            )
            colorBalanceSection(
                titleKey: "imageEditor.colorBalance.midtones",
                cyanRed: $viewModel.colorBalanceMidtonesCyanRed,
                magentaGreen: $viewModel.colorBalanceMidtonesMagentaGreen,
                yellowBlue: $viewModel.colorBalanceMidtonesYellowBlue
            )
            colorBalanceSection(
                titleKey: "imageEditor.colorBalance.highlights",
                cyanRed: $viewModel.colorBalanceHighlightsCyanRed,
                magentaGreen: $viewModel.colorBalanceHighlightsMagentaGreen,
                yellowBlue: $viewModel.colorBalanceHighlightsYellowBlue
            )
        }
    }

    private var blackWhiteControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            adjustmentSlider(
                labelKey: "imageEditor.blackWhite.reds",
                value: $viewModel.blackWhiteReds,
                range: 0...2,
                step: 0.05,
                displayText: "\(Int((viewModel.blackWhiteReds * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.blackWhite.yellows",
                value: $viewModel.blackWhiteYellows,
                range: 0...2,
                step: 0.05,
                displayText: "\(Int((viewModel.blackWhiteYellows * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.blackWhite.greens",
                value: $viewModel.blackWhiteGreens,
                range: 0...2,
                step: 0.05,
                displayText: "\(Int((viewModel.blackWhiteGreens * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.blackWhite.cyans",
                value: $viewModel.blackWhiteCyans,
                range: 0...2,
                step: 0.05,
                displayText: "\(Int((viewModel.blackWhiteCyans * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.blackWhite.blues",
                value: $viewModel.blackWhiteBlues,
                range: 0...2,
                step: 0.05,
                displayText: "\(Int((viewModel.blackWhiteBlues * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.blackWhite.magentas",
                value: $viewModel.blackWhiteMagentas,
                range: 0...2,
                step: 0.05,
                displayText: "\(Int((viewModel.blackWhiteMagentas * 100).rounded()))%"
            )
        }
    }

    private var hueSaturationControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(L10n.text("imageEditor.hueSaturation.colorize"), isOn: $viewModel.hueSaturationColorize)
                .toggleStyle(.checkbox)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            adjustmentSlider(
                labelKey: "imageEditor.hueSaturation.hue",
                value: $viewModel.hueSaturationHue,
                range: -180...180,
                step: 1,
                displayText: "\(Int(viewModel.hueSaturationHue.rounded()))°"
            )
            adjustmentSlider(
                labelKey: "imageEditor.hueSaturation.saturation",
                value: $viewModel.hueSaturationSaturation,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.hueSaturationSaturation * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.hueSaturation.lightness",
                value: $viewModel.hueSaturationLightness,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.hueSaturationLightness * 100).rounded()))%"
            )
        }
    }

    private var channelMixerControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(L10n.text("imageEditor.channelMixer.monochrome"), isOn: $viewModel.channelMixerMonochrome)
                .toggleStyle(.checkbox)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .onChange(of: viewModel.channelMixerMonochrome) { _, isMonochrome in
                    viewModel.selectedChannelMixerOutput = isMonochrome ? .monochrome : .red
                }
            if viewModel.channelMixerMonochrome {
                channelMixerSliderGroup(
                    red: $viewModel.channelMixerMonoRed,
                    green: $viewModel.channelMixerMonoGreen,
                    blue: $viewModel.channelMixerMonoBlue,
                    constant: $viewModel.channelMixerMonoConstant
                )
            } else {
                Picker(L10n.text("imageEditor.channelMixer.output"), selection: $viewModel.selectedChannelMixerOutput) {
                    ForEach(ImageEditorChannelMixerOutput.allCases.filter { $0 != .monochrome }) { output in
                        Text(output.title).tag(output)
                    }
                }
                if viewModel.selectedChannelMixerOutput == .red {
                    channelMixerSliderGroup(
                        red: $viewModel.channelMixerRedRed,
                        green: $viewModel.channelMixerRedGreen,
                        blue: $viewModel.channelMixerRedBlue,
                        constant: $viewModel.channelMixerRedConstant
                    )
                } else if viewModel.selectedChannelMixerOutput == .green {
                    channelMixerSliderGroup(
                        red: $viewModel.channelMixerGreenRed,
                        green: $viewModel.channelMixerGreenGreen,
                        blue: $viewModel.channelMixerGreenBlue,
                        constant: $viewModel.channelMixerGreenConstant
                    )
                } else {
                    channelMixerSliderGroup(
                        red: $viewModel.channelMixerBlueRed,
                        green: $viewModel.channelMixerBlueGreen,
                        blue: $viewModel.channelMixerBlueBlue,
                        constant: $viewModel.channelMixerBlueConstant
                    )
                }
            }
        }
    }

    private var photoFilterControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(L10n.text("imageEditor.photoFilter.preset"), selection: $viewModel.selectedPhotoFilterPreset) {
                ForEach(ImageEditorPhotoFilterPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            adjustmentSlider(
                labelKey: "imageEditor.photoFilter.density",
                value: $viewModel.photoFilterDensity,
                range: 0...1,
                step: 0.05,
                displayText: "\(Int((viewModel.photoFilterDensity * 100).rounded()))%"
            )
            Toggle(L10n.text("imageEditor.photoFilter.preserveLuminosity"), isOn: $viewModel.photoFilterPreserveLuminosity)
                .toggleStyle(.checkbox)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            if viewModel.selectedPhotoFilterPreset == .custom {
                adjustmentSlider(
                    labelKey: "imageEditor.photoFilter.customRed",
                    value: $viewModel.photoFilterCustomRed,
                    range: 0...1,
                    step: 0.05,
                    displayText: "\(Int((viewModel.photoFilterCustomRed * 100).rounded()))%"
                )
                adjustmentSlider(
                    labelKey: "imageEditor.photoFilter.customGreen",
                    value: $viewModel.photoFilterCustomGreen,
                    range: 0...1,
                    step: 0.05,
                    displayText: "\(Int((viewModel.photoFilterCustomGreen * 100).rounded()))%"
                )
                adjustmentSlider(
                    labelKey: "imageEditor.photoFilter.customBlue",
                    value: $viewModel.photoFilterCustomBlue,
                    range: 0...1,
                    step: 0.05,
                    displayText: "\(Int((viewModel.photoFilterCustomBlue * 100).rounded()))%"
                )
            }
        }
    }

    private var colorLookupControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(L10n.text("imageEditor.colorLookup.preset"), selection: $viewModel.selectedColorLookupPreset) {
                ForEach(ImageEditorColorLookupPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            HStack(spacing: 8) {
                Button(L10n.text("imageEditor.action.colorLookupImportCube")) {
                    viewModel.chooseColorLookupCubeFile()
                }
                .buttonStyle(EditorTextButtonStyle())
                Text(colorLookupCubeStatusText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .lineLimit(1)
            }
        }
    }

    private var colorLookupCubeStatusText: String {
        guard viewModel.selectedColorLookupCube.isValid else {
            return L10n.text("imageEditor.colorLookup.cubeMissing")
        }
        return L10n.format(
            "imageEditor.colorLookup.cubeLoaded",
            viewModel.selectedColorLookupCube.name,
            viewModel.selectedColorLookupCube.dimension
        )
    }

    private var posterizeControls: some View {
        adjustmentSlider(
            labelKey: "imageEditor.option.posterizeLevels",
            value: posterizeLevelBinding,
            range: 2...32,
            step: 1,
            displayText: "\(Int(posterizeLevelBinding.wrappedValue.rounded()))"
        )
    }

    private var shadowsHighlightsControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            adjustmentSlider(
                labelKey: "imageEditor.shadowsHighlights.shadows",
                value: $viewModel.shadowsHighlightsShadows,
                range: 0...1,
                step: 0.05,
                displayText: "\(Int((viewModel.shadowsHighlightsShadows * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.shadowsHighlights.highlights",
                value: $viewModel.shadowsHighlightsHighlights,
                range: 0...1,
                step: 0.05,
                displayText: "\(Int((viewModel.shadowsHighlightsHighlights * 100).rounded()))%"
            )
        }
    }

    private var exposureControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            adjustmentSlider(
                labelKey: "imageEditor.exposure.exposure",
                value: $viewModel.exposureEV,
                range: -5...5,
                step: 0.05,
                displayText: String(format: "%+.2f", viewModel.exposureEV)
            )
            adjustmentSlider(
                labelKey: "imageEditor.exposure.offset",
                value: $viewModel.exposureOffset,
                range: -0.5...0.5,
                step: 0.01,
                displayText: String(format: "%+.2f", viewModel.exposureOffset)
            )
            adjustmentSlider(
                labelKey: "imageEditor.exposure.gamma",
                value: $viewModel.exposureGamma,
                range: 0.1...9.99,
                step: 0.01,
                displayText: String(format: "%.2f", viewModel.exposureGamma)
            )
        }
    }

    private var brightnessContrastControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            adjustmentSlider(
                labelKey: "imageEditor.brightnessContrast.brightness",
                value: $viewModel.brightnessContrastBrightness,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.brightnessContrastBrightness * 100).rounded()))"
            )
            adjustmentSlider(
                labelKey: "imageEditor.brightnessContrast.contrast",
                value: $viewModel.brightnessContrastContrast,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((viewModel.brightnessContrastContrast * 100).rounded()))"
            )
        }
    }

    private var selectiveColorControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(L10n.text("imageEditor.selectiveColor.range"), selection: $viewModel.selectedSelectiveColorRange) {
                ForEach(ImageEditorSelectiveColorRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            Picker(L10n.text("imageEditor.selectiveColor.method"), selection: $viewModel.selectiveColorMethod) {
                ForEach(ImageEditorSelectiveColorMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }
            ForEach(ImageEditorSelectiveColorComponent.allCases) { component in
                let binding = selectiveColorBinding(component)
                adjustmentSlider(
                    labelKey: "imageEditor.selectiveColor.component.\(component.rawValue)",
                    value: binding,
                    range: -1...1,
                    step: 0.05,
                    displayText: "\(Int((binding.wrappedValue * 100).rounded()))%"
                )
            }
        }
    }

    private var gradientMapControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(L10n.text("imageEditor.gradientMap.preset"), selection: $viewModel.selectedGradientMapPreset) {
                ForEach(ImageEditorGradientMapPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            Toggle(L10n.text("imageEditor.gradientMap.reverse"), isOn: $viewModel.gradientMapReverse)
                .toggleStyle(.checkbox)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            if viewModel.selectedGradientMapPreset == .custom {
                Text(L10n.text("imageEditor.gradientMap.shadows"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                gradientMapColorSliders(
                    red: $viewModel.gradientMapShadowRed,
                    green: $viewModel.gradientMapShadowGreen,
                    blue: $viewModel.gradientMapShadowBlue
                )
                Text(L10n.text("imageEditor.gradientMap.highlights"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                gradientMapColorSliders(
                    red: $viewModel.gradientMapHighlightRed,
                    green: $viewModel.gradientMapHighlightGreen,
                    blue: $viewModel.gradientMapHighlightBlue
                )
            }
        }
    }

    private func selectiveColorBinding(_ component: ImageEditorSelectiveColorComponent) -> Binding<Double> {
        Binding {
            let values = viewModel.selectiveColorSettings.values(for: viewModel.selectedSelectiveColorRange)
            switch component {
            case .cyan:
                return values.cyan
            case .magenta:
                return values.magenta
            case .yellow:
                return values.yellow
            case .black:
                return values.black
            }
        } set: { newValue in
            var settings = viewModel.selectiveColorSettings
            var values = settings.values(for: viewModel.selectedSelectiveColorRange)
            let clamped = max(-1, min(1, newValue))
            switch component {
            case .cyan:
                values.cyan = clamped
            case .magenta:
                values.magenta = clamped
            case .yellow:
                values.yellow = clamped
            case .black:
                values.black = clamped
            }
            settings.setValues(values, for: viewModel.selectedSelectiveColorRange)
            viewModel.selectiveColorSettings = settings
        }
    }

    private func gradientMapColorSliders(
        red: Binding<Double>,
        green: Binding<Double>,
        blue: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            adjustmentSlider(
                labelKey: "imageEditor.gradientMap.red",
                value: red,
                range: 0...1,
                step: 0.05,
                displayText: "\(Int((red.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.gradientMap.green",
                value: green,
                range: 0...1,
                step: 0.05,
                displayText: "\(Int((green.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.gradientMap.blue",
                value: blue,
                range: 0...1,
                step: 0.05,
                displayText: "\(Int((blue.wrappedValue * 100).rounded()))%"
            )
        }
    }

    private func colorBalanceSection(
        titleKey: String,
        cyanRed: Binding<Double>,
        magentaGreen: Binding<Double>,
        yellowBlue: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.text(titleKey))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            adjustmentSlider(
                labelKey: "imageEditor.colorBalance.cyanRed",
                value: cyanRed,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((cyanRed.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.colorBalance.magentaGreen",
                value: magentaGreen,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((magentaGreen.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.colorBalance.yellowBlue",
                value: yellowBlue,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((yellowBlue.wrappedValue * 100).rounded()))%"
            )
        }
    }

    private func channelMixerSliderGroup(
        red: Binding<Double>,
        green: Binding<Double>,
        blue: Binding<Double>,
        constant: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            adjustmentSlider(
                labelKey: "imageEditor.channelMixer.red",
                value: red,
                range: -2...2,
                step: 0.05,
                displayText: "\(Int((red.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.channelMixer.green",
                value: green,
                range: -2...2,
                step: 0.05,
                displayText: "\(Int((green.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.channelMixer.blue",
                value: blue,
                range: -2...2,
                step: 0.05,
                displayText: "\(Int((blue.wrappedValue * 100).rounded()))%"
            )
            adjustmentSlider(
                labelKey: "imageEditor.channelMixer.constant",
                value: constant,
                range: -1...1,
                step: 0.05,
                displayText: "\(Int((constant.wrappedValue * 100).rounded()))%"
            )
        }
    }

    private func levelsSlider(
        labelKey: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        displayText: String
    ) -> some View {
        adjustmentSlider(labelKey: labelKey, value: value, range: range, step: step, displayText: displayText)
    }

    private func adjustmentSlider(
        labelKey: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        displayText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(L10n.text(labelKey))
                Spacer()
                Text(verbatim: displayText)
                    .monospacedDigit()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            Slider(value: value, in: range, step: step)
        }
    }

    private var posterizeLevelBinding: Binding<Double> {
        Binding {
            Double(NSImage.posterizeLevelCount(from: viewModel.adjustmentValue))
        } set: { newValue in
            viewModel.adjustmentValue = Double(max(2, min(32, Int(newValue.rounded()))))
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

    func closeWindow() {
        NSApplication.shared.keyWindow?.close()
    }
}

struct DisabledMaskSlash: View {
    var body: some View {
        Rectangle()
            .fill(Color.red.opacity(0.85))
            .frame(width: 30, height: 3)
            .rotationEffect(.degrees(-38))
            .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 0)
    }
}

struct EditorPanel<Content: View>: View {
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

struct EditorIconButtonStyle: ButtonStyle {
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

struct EditorTextButtonStyle: ButtonStyle {
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

struct EditorPrimaryButtonStyle: ButtonStyle {
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

private struct ImageEditorGuideDrag {
    var orientation: ImageEditorGuideOrientation
    var position: CGFloat
}
