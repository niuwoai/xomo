//
//  RegionScreenshotCapture.swift
//  veilpic
//
//  Created by Codex on 2026/6/30.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class RegionScreenshotCapture: NSObject, NSWindowDelegate {
    static let shared = RegionScreenshotCapture()

    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    private var completion: ((NSImage?) -> Void)?
    private var isActive = false

    private override init() {
        super.init()
    }

    var isCapturing: Bool {
        isActive
    }

    func start(completion: @escaping (NSImage?) -> Void) {
        guard !isActive else {
            bringToFront()
            return
        }

        self.completion = completion
        isActive = true
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        createOverlayWindows()
        installKeyMonitor()
        bringToFront()
    }

    private func createOverlayWindows() {
        windows = NSScreen.screens.map { screen in
            let view = RegionCaptureOverlayView(
                screenFrame: screen.frame,
                onComplete: { [weak self] globalRect, selection, annotations in
                    self?.completeCapture(globalRect: globalRect, selection: selection, annotations: annotations)
                },
                onCopy: { [weak self] globalRect, selection, annotations, reply in
                    self?.copyCapture(globalRect: globalRect, selection: selection, annotations: annotations, reply: reply)
                },
                onSave: { [weak self] globalRect, selection, annotations in
                    self?.saveCapture(globalRect: globalRect, selection: selection, annotations: annotations)
                },
                onCancel: { [weak self] in
                    self?.cancel()
                }
            )

            let panel = RegionCapturePanel(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = false
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.acceptsMouseMovedEvents = true
            panel.delegate = self
            panel.contentView = NSHostingView(rootView: view)
            panel.setFrame(screen.frame, display: true)
            return panel
        }
    }

    private func bringToFront() {
        windows.forEach { window in
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.cancel()
                return nil
            }

            return event
        }
    }

    private func completeCapture(globalRect: CGRect, selection: CGRect, annotations: [RegionCaptureAnnotation]) {
        let normalized = globalRect.standardized
        guard normalized.width >= 8, normalized.height >= 8 else {
            cancel()
            return
        }

        let excluded = Set(windows.map(\.windowNumber))
        cleanupWindows()

        Task { [weak self] in
            let image = await self?.captureAnnotatedImage(
                globalRect: normalized,
                selection: selection,
                annotations: annotations,
                excludingWindowNumbers: excluded
            )
            await MainActor.run {
                self?.finish(image)
            }
        }
    }

    private func copyCapture(
        globalRect: CGRect,
        selection: CGRect,
        annotations: [RegionCaptureAnnotation],
        reply: @escaping (Bool) -> Void
    ) {
        let normalized = globalRect.standardized
        guard normalized.width >= 8, normalized.height >= 8 else {
            reply(false)
            return
        }

        let excluded = Set(windows.map(\.windowNumber))
        Task { [weak self] in
            guard let image = await self?.captureAnnotatedImage(
                globalRect: normalized,
                selection: selection,
                annotations: annotations,
                excludingWindowNumbers: excluded
            ) else {
                await MainActor.run { reply(false) }
                return
            }

            let copied = ClipboardImageWriter.copy(
                image,
                preferredFileName: "musepic-annotated-screenshot.png"
            )
            await MainActor.run { reply(copied) }
        }
    }

    private func saveCapture(globalRect: CGRect, selection: CGRect, annotations: [RegionCaptureAnnotation]) {
        let normalized = globalRect.standardized
        guard normalized.width >= 8, normalized.height >= 8 else {
            cancel()
            return
        }

        let excluded = Set(windows.map(\.windowNumber))
        cleanupWindows()

        Task { [weak self] in
            let image = await self?.captureAnnotatedImage(
                globalRect: normalized,
                selection: selection,
                annotations: annotations,
                excludingWindowNumbers: excluded
            )
            await MainActor.run {
                if let image {
                    self?.save(image)
                }
                self?.finish(image)
            }
        }
    }

    private func captureAnnotatedImage(
        globalRect: CGRect,
        selection: CGRect,
        annotations: [RegionCaptureAnnotation],
        excludingWindowNumbers: Set<Int>
    ) async -> NSImage? {
        guard let image = await ScreenshotCaptureCoordinator.shared.captureGlobalRect(
            globalRect,
            excludingWindowNumbers: excludingWindowNumbers
        ) else {
            return nil
        }

        return RegionAnnotationRenderer().render(baseImage: image, selection: selection, annotations: annotations)
    }

    private func save(_ image: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "musepic_Annotated_\(Int(Date().timeIntervalSince1970)).png"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        guard let tiffData = image.tiffRepresentation,
              let representation = NSBitmapImageRep(data: tiffData),
              let data = representation.representation(using: .png, properties: [:])
        else {
            NSSound.beep()
            return
        }

        do {
            try data.write(to: url)
        } catch {
            NSSound.beep()
        }
    }

    private func cancel() {
        cleanupWindows()
        finish(nil)
    }

    private func cleanupWindows() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }

        windows.forEach { window in
            window.delegate = nil
            window.close()
        }
        windows = []
        isActive = false
        DockVisibilitySettings.shared.applyActivationPolicy()
    }

    private func finish(_ image: NSImage?) {
        let callback = completion
        completion = nil
        callback?(image)
    }

    func windowWillClose(_ notification: Notification) {
        guard isActive else { return }
        guard let closedWindow = notification.object as? NSWindow else { return }
        windows.removeAll { $0 === closedWindow }
        if windows.isEmpty {
            cancel()
        }
    }
}

private final class RegionCapturePanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

private struct RegionCaptureOverlayView: View {
    let screenFrame: CGRect
    let onComplete: (CGRect, CGRect, [RegionCaptureAnnotation]) -> Void
    let onCopy: (CGRect, CGRect, [RegionCaptureAnnotation], @escaping (Bool) -> Void) -> Void
    let onSave: (CGRect, CGRect, [RegionCaptureAnnotation]) -> Void
    let onCancel: () -> Void

    @State private var selection: CGRect = .zero
    @State private var interaction: RegionSelectionInteraction = .idle
    @State private var mode: RegionCaptureMode = .selecting
    @State private var selectedTool: RegionAnnotationTool = .move
    @State private var annotations: [RegionCaptureAnnotation] = []
    @State private var draftAnnotation: RegionCaptureAnnotation?
    @State private var undoStack: [[RegionCaptureAnnotation]] = []
    @State private var redoStack: [[RegionCaptureAnnotation]] = []
    @State private var strokeColor: NSColor = .systemRed
    @State private var fillColor: NSColor?
    @State private var lineWidth: CGFloat = 3
    @State private var fontSize: CGFloat = 18
    @State private var activeTextID: UUID?
    @FocusState private var textEditorFocused: Bool

    var body: some View {
        ZStack {
            dimmingLayer
            annotationLayer
            selectionLayer
            textEditorLayer
            instructionLayer
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    handleDragChanged(value)
                }
                .onEnded { value in
                    handleDragEnded(value)
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    completeFromDoubleClick()
                }
        )
        .onChange(of: activeTextID) { _, _ in
            focusTextEditorIfNeeded()
        }
        .onChange(of: selectedTool) { _, _ in
            finishTextEditing()
        }
    }

    private var dimmingLayer: some View {
        Rectangle()
            .fill(Color.black.opacity(mode == .annotating ? 0.40 : 0.34))
            .overlay {
                if !selection.isEmpty {
                    Rectangle()
                        .frame(width: selection.width, height: selection.height)
                        .position(x: selection.midX, y: selection.midY)
                        .blendMode(.destinationOut)
                }
            }
            .compositingGroup()
    }

    @ViewBuilder
    private var selectionLayer: some View {
        if !selection.isEmpty {
            Rectangle()
                .strokeBorder(Color.white, lineWidth: 1.5)
                .background(Color.white.opacity(0.05))
                .frame(width: selection.width, height: selection.height)
                .position(x: selection.midX, y: selection.midY)

            resizeHandles

            sizeBadge
                .position(badgePosition)

            if mode == .annotating {
                toolbar
                    .position(toolbarPosition)
            }
        }
    }

    @ViewBuilder
    private var annotationLayer: some View {
        if mode == .annotating {
            Canvas { context, _ in
                for annotation in annotations {
                    draw(annotation, in: &context)
                }
                if let draftAnnotation {
                    draw(draftAnnotation, in: &context)
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var textEditorLayer: some View {
        if let activeText = activeTextAnnotation {
            TextField("", text: textBinding(for: activeText), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: activeText.fontSize, weight: .semibold))
                .foregroundStyle(Color(nsColor: activeText.strokeColor))
                .lineLimit(1...6)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(width: max(120, textRect(activeText).width), height: max(32, textRect(activeText).height), alignment: .leading)
                .background(Color.white.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Color(nsColor: activeText.strokeColor).opacity(0.85))
                }
                .position(x: textRect(activeText).midX, y: textRect(activeText).midY)
                .focused($textEditorFocused)
                .onSubmit {
                    finishTextEditing()
                }
                .onAppear {
                    focusTextEditorIfNeeded()
                }
        }
    }

    private var activeTextAnnotation: RegionCaptureAnnotation? {
        guard let activeTextID else { return nil }
        return annotations.first { annotation in
            guard annotation.id == activeTextID else { return false }
            if case .text = annotation.kind {
                return true
            }
            return false
        }
    }

    private func textRect(_ annotation: RegionCaptureAnnotation) -> CGRect {
        if case let .text(_, rect) = annotation.kind {
            return rect
        }
        return .zero
    }

    private func textBinding(for annotation: RegionCaptureAnnotation) -> Binding<String> {
        Binding(
            get: {
                guard let current = annotations.first(where: { $0.id == annotation.id }),
                      case let .text(text, _) = current.kind
                else {
                    return ""
                }
                return text
            },
            set: { newText in
                updateText(annotationID: annotation.id, text: newText)
            }
        )
    }

    private func updateText(annotationID: UUID, text: String) {
        guard let index = annotations.firstIndex(where: { $0.id == annotationID }),
              case let .text(_, rect) = annotations[index].kind
        else {
            return
        }

        let font = NSFont.systemFont(ofSize: annotations[index].fontSize, weight: .semibold)
        let measured = (text.isEmpty ? " " : text).size(withAttributes: [.font: font])
        let maxWidth = max(120, selection.maxX - rect.minX - 8)
        let nextRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: min(max(120, measured.width + 22), maxWidth),
            height: max(32, measured.height + 14)
        )
        annotations[index].kind = .text(text, constrained(nextRect, within: selection))
    }

    private func focusTextEditorIfNeeded() {
        guard activeTextID != nil else {
            textEditorFocused = false
            return
        }
        DispatchQueue.main.async {
            textEditorFocused = true
        }
    }

    private func finishTextEditing() {
        guard let activeTextID else { return }
        if let index = annotations.firstIndex(where: { $0.id == activeTextID }),
           case let .text(text, _) = annotations[index].kind,
           text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            annotations.remove(at: index)
        }
        self.activeTextID = nil
        textEditorFocused = false
    }

    private var toolbar: some View {
        RegionAnnotationToolbarView(
            selectedTool: $selectedTool,
            strokeColor: $strokeColor,
            fillColor: $fillColor,
            lineWidth: $lineWidth,
            fontSize: $fontSize,
            canUndo: !undoStack.isEmpty,
            canRedo: !redoStack.isEmpty,
            onUndo: undo,
            onRedo: redo,
            onCopy: { reply in
                finishTextEditing()
                onCopy(globalRect(fromLocalRect: selection), selection, annotations, reply)
            },
            onSave: {
                finishTextEditing()
                onSave(globalRect(fromLocalRect: selection), selection, annotations)
            },
            onComplete: {
                finishTextEditing()
                onComplete(globalRect(fromLocalRect: selection), selection, annotations)
            },
            onCancel: onCancel
        )
    }

    private var instructionLayer: some View {
        VStack(spacing: 8) {
            Image(systemName: "selection.pin.in.out")
                .font(.system(size: 30, weight: .semibold))
            Text(L10n.text("screenshot.region.instruction.title"))
                .font(.headline)
            Text(mode == .selecting ? L10n.text("screenshot.region.instruction.subtitle") : L10n.text("captureToolbar.instruction.annotating"))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(selection.isEmpty ? 1 : 0)
    }

    private var sizeBadge: some View {
        Text("\(Int(selection.width.rounded())) x \(Int(selection.height.rounded()))")
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.54))
            .clipShape(Capsule())
    }

    private var resizeHandles: some View {
        ForEach(RegionResizeHandle.allCases) { handle in
            Circle()
                .fill(Color.white)
                .frame(width: handle.visualSize, height: handle.visualSize)
                .overlay {
                    Circle()
                        .strokeBorder(AppTheme.accent, lineWidth: 2)
                }
                .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
                .position(handle.position(in: selection))
        }
    }

    private var badgePosition: CGPoint {
        let x = min(max(selection.midX, 58), screenFrame.width - 58)
        let y = max(selection.minY - 18, 20)
        return CGPoint(x: x, y: y)
    }

    private var toolbarPosition: CGPoint {
        let estimatedWidth: CGFloat = selectedTool == .text ? 760 : 650
        let estimatedHeight: CGFloat = 72
        let x = min(max(selection.midX, estimatedWidth / 2 + 12), screenFrame.width - estimatedWidth / 2 - 12)
        let preferredY = selection.maxY + estimatedHeight / 2 + 14
        let y = preferredY < screenFrame.height - 18 ? preferredY : max(selection.minY - estimatedHeight / 2 - 14, estimatedHeight / 2 + 12)
        return CGPoint(x: x, y: y)
    }

    private func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        if case .idle = interaction {
            interaction = interactionForStartLocation(value.startLocation)
        }

        switch interaction {
        case let .drawing(start):
            selection = constrained(rect(from: start, to: value.location))
        case let .moving(startSelection):
            let movedSelection = moved(startSelection, by: value.translation)
            let delta = CGSize(width: movedSelection.minX - selection.minX, height: movedSelection.minY - selection.minY)
            selection = movedSelection
            translateAnnotations(by: delta)
        case let .movingAnnotation(id, startAnnotations):
            annotations = movedAnnotations(startAnnotations, annotationID: id, by: value.translation)
        case let .resizing(handle, startSelection):
            selection = resized(startSelection, handle: handle, translation: value.translation)
        case let .annotating(start):
            updateDraftAnnotation(from: start, to: value.location)
        case .idle:
            break
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        handleDragChanged(value)
        defer {
            interaction = .idle
            draftAnnotation = nil
        }

        if mode == .selecting {
            if selection.width < 8 || selection.height < 8 {
                selection = .zero
                return
            }
            mode = .annotating
            selectedTool = .move
            return
        }

        guard mode == .annotating else { return }
        switch interaction {
        case .annotating:
            if isClick(value) {
                handleTap(at: value.location)
            } else if let draftAnnotation {
                commit(draftAnnotation)
            }
        case .moving, .movingAnnotation, .resizing:
            break
        case .drawing:
            mode = .annotating
        case .idle:
            if isClick(value) {
                handleTap(at: value.location)
            }
        }
    }

    private func isClick(_ value: DragGesture.Value) -> Bool {
        abs(value.translation.width) < 3 && abs(value.translation.height) < 3
    }

    private func interactionForStartLocation(_ point: CGPoint) -> RegionSelectionInteraction {
        if mode == .selecting {
            return .drawing(point)
        }

        if let handle = resizeHandle(at: point) {
            finishTextEditing()
            return .resizing(handle: handle, startSelection: selection)
        }

        if selectedTool == .move, let id = annotationID(at: point) {
            finishTextEditing()
            return .movingAnnotation(id: id, startAnnotations: annotations)
        }

        if selectedTool == .move, selection.contains(point) {
            finishTextEditing()
            return .moving(startSelection: selection)
        }

        if selection.contains(point), selectedTool != .move, selectedTool != .text {
            finishTextEditing()
            return .annotating(start: point)
        }

        return .idle
    }

    private func handleTap(at point: CGPoint) {
        guard mode == .annotating else { return }
        guard selection.contains(point) else {
            finishTextEditing()
            return
        }

        guard selectedTool == .text else {
            finishTextEditing()
            return
        }

        if let existing = annotations.reversed().first(where: { annotation in
            if case let .text(_, rect) = annotation.kind {
                return rect.contains(point)
            }
            return false
        }) {
            activeTextID = existing.id
            return
        }

        finishTextEditing()
        let textBox = constrained(
            CGRect(x: point.x, y: point.y, width: 140, height: max(32, fontSize + 14)),
            within: selection
        )
        let annotation = RegionCaptureAnnotation(
            kind: .text("", textBox),
            strokeColor: strokeColor,
            fillColor: nil,
            lineWidth: lineWidth,
            fontSize: fontSize
        )
        commit(annotation)
        activeTextID = annotation.id
    }

    private func completeFromDoubleClick() {
        guard mode == .annotating, !selection.isEmpty else { return }
        finishTextEditing()
        onComplete(globalRect(fromLocalRect: selection), selection, annotations)
    }

    private func updateDraftAnnotation(from start: CGPoint, to current: CGPoint) {
        let end = constrained(current, within: selection)

        switch selectedTool {
        case .rectangle:
            let draftRect = rect(from: start, to: end)
            guard draftRect.width >= 2, draftRect.height >= 2 else {
                draftAnnotation = nil
                return
            }
            draftAnnotation = RegionCaptureAnnotation(kind: .rectangle(draftRect), strokeColor: strokeColor, fillColor: fillColor, lineWidth: lineWidth, fontSize: fontSize)
        case .ellipse:
            let draftRect = rect(from: start, to: end)
            guard draftRect.width >= 2, draftRect.height >= 2 else {
                draftAnnotation = nil
                return
            }
            draftAnnotation = RegionCaptureAnnotation(kind: .ellipse(draftRect), strokeColor: strokeColor, fillColor: fillColor, lineWidth: lineWidth, fontSize: fontSize)
        case .brush:
            var points: [CGPoint] = []
            if case let .brush(existingPoints) = draftAnnotation?.kind {
                points = existingPoints
            } else {
                points = [start]
            }
            points.append(end)
            draftAnnotation = RegionCaptureAnnotation(kind: .brush(points), strokeColor: strokeColor, fillColor: nil, lineWidth: lineWidth, fontSize: fontSize)
        case .move, .text:
            draftAnnotation = nil
        }
    }

    private func draw(_ annotation: RegionCaptureAnnotation, in context: inout GraphicsContext) {
        let strokeColor = Color(nsColor: annotation.strokeColor)
        let fillColor = annotation.fillColor.map { Color(nsColor: $0) }
        let stroke = StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round, lineJoin: .round)

        switch annotation.kind {
        case let .rectangle(rect):
            let path = Path(rect)
            if let fillColor {
                context.fill(path, with: .color(fillColor))
            }
            context.stroke(path, with: .color(strokeColor), style: stroke)
        case let .ellipse(rect):
            let path = Path(ellipseIn: rect)
            if let fillColor {
                context.fill(path, with: .color(fillColor))
            }
            context.stroke(path, with: .color(strokeColor), style: stroke)
        case let .brush(points):
            guard let first = points.first else { return }
            var path = Path()
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(path, with: .color(strokeColor), style: stroke)
        case let .text(text, rect):
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            context.draw(
                Text(text)
                    .font(.system(size: annotation.fontSize, weight: .semibold))
                    .foregroundStyle(strokeColor),
                in: rect
            )
        }
    }

    private func commit(_ annotation: RegionCaptureAnnotation) {
        undoStack.append(annotations)
        redoStack.removeAll()
        annotations.append(annotation)
    }

    private func undo() {
        guard !undoStack.isEmpty else { return }
        finishTextEditing()
        redoStack.append(annotations)
        annotations = undoStack.removeLast()
    }

    private func redo() {
        guard !redoStack.isEmpty else { return }
        finishTextEditing()
        undoStack.append(annotations)
        annotations = redoStack.removeLast()
    }

    private func translateAnnotations(by delta: CGSize) {
        guard delta != .zero else { return }
        annotations = annotations.map { annotation in
            var next = annotation
            switch annotation.kind {
            case let .rectangle(rect):
                next.kind = .rectangle(rect.offsetBy(dx: delta.width, dy: delta.height))
            case let .ellipse(rect):
                next.kind = .ellipse(rect.offsetBy(dx: delta.width, dy: delta.height))
            case let .brush(points):
                next.kind = .brush(points.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) })
            case let .text(text, rect):
                next.kind = .text(text, rect.offsetBy(dx: delta.width, dy: delta.height))
            }
            return next
        }
    }

    private func movedAnnotations(
        _ startAnnotations: [RegionCaptureAnnotation],
        annotationID: UUID,
        by translation: CGSize
    ) -> [RegionCaptureAnnotation] {
        startAnnotations.map { annotation in
            guard annotation.id == annotationID else { return annotation }
            var next = annotation
            switch annotation.kind {
            case let .rectangle(rect):
                next.kind = .rectangle(constrained(rect.offsetBy(dx: translation.width, dy: translation.height), within: selection))
            case let .ellipse(rect):
                next.kind = .ellipse(constrained(rect.offsetBy(dx: translation.width, dy: translation.height), within: selection))
            case let .brush(points):
                next.kind = .brush(points.map { point in
                    constrained(CGPoint(x: point.x + translation.width, y: point.y + translation.height), within: selection)
                })
            case let .text(text, rect):
                next.kind = .text(text, constrained(rect.offsetBy(dx: translation.width, dy: translation.height), within: selection))
            }
            return next
        }
    }

    private func annotationID(at point: CGPoint) -> UUID? {
        annotations.reversed().first { annotation in
            switch annotation.kind {
            case let .rectangle(rect), let .ellipse(rect), let .text(_, rect):
                return rect.insetBy(dx: -6, dy: -6).contains(point)
            case let .brush(points):
                guard !points.isEmpty else { return false }
                let bounds = points.dropFirst().reduce(CGRect(origin: points[0], size: .zero)) { partial, point in
                    partial.union(CGRect(origin: point, size: .zero))
                }
                return bounds.insetBy(dx: -max(10, annotation.lineWidth), dy: -max(10, annotation.lineWidth)).contains(point)
            }
        }?.id
    }

    private func resizeHandle(at point: CGPoint) -> RegionResizeHandle? {
        let hitSize: CGFloat = 18
        return RegionResizeHandle.allCases.first { handle in
            let position = handle.position(in: selection)
            return abs(point.x - position.x) <= hitSize && abs(point.y - position.y) <= hitSize
        }
    }

    private func moved(_ startSelection: CGRect, by translation: CGSize) -> CGRect {
        let maxX = max(screenFrame.width - startSelection.width, 0)
        let maxY = max(screenFrame.height - startSelection.height, 0)
        let nextOrigin = CGPoint(
            x: (startSelection.minX + translation.width).clamped(to: 0...maxX),
            y: (startSelection.minY + translation.height).clamped(to: 0...maxY)
        )
        return CGRect(origin: nextOrigin, size: startSelection.size)
    }

    private func resized(_ startSelection: CGRect, handle: RegionResizeHandle, translation: CGSize) -> CGRect {
        var minX = startSelection.minX
        var maxX = startSelection.maxX
        var minY = startSelection.minY
        var maxY = startSelection.maxY

        if handle.movesLeft {
            minX += translation.width
        }
        if handle.movesRight {
            maxX += translation.width
        }
        if handle.movesTop {
            minY += translation.height
        }
        if handle.movesBottom {
            maxY += translation.height
        }

        let minimumSize: CGFloat = 8
        minX = minX.clamped(to: 0...screenFrame.width)
        maxX = maxX.clamped(to: 0...screenFrame.width)
        minY = minY.clamped(to: 0...screenFrame.height)
        maxY = maxY.clamped(to: 0...screenFrame.height)

        if maxX - minX < minimumSize {
            if handle.movesLeft {
                minX = max(maxX - minimumSize, 0)
            } else {
                maxX = min(minX + minimumSize, screenFrame.width)
            }
        }

        if maxY - minY < minimumSize {
            if handle.movesTop {
                minY = max(maxY - minimumSize, 0)
            } else {
                maxY = min(minY + minimumSize, screenFrame.height)
            }
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).standardized
    }

    private func constrained(_ rect: CGRect) -> CGRect {
        constrained(rect, within: CGRect(origin: .zero, size: screenFrame.size))
    }

    private func constrained(_ rect: CGRect, within bounds: CGRect) -> CGRect {
        let normalized = rect.standardized
        let minX = normalized.minX.clamped(to: bounds.minX...bounds.maxX)
        let maxX = normalized.maxX.clamped(to: bounds.minX...bounds.maxX)
        let minY = normalized.minY.clamped(to: bounds.minY...bounds.maxY)
        let maxY = normalized.maxY.clamped(to: bounds.minY...bounds.maxY)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).standardized
    }

    private func constrained(_ point: CGPoint, within bounds: CGRect) -> CGPoint {
        CGPoint(
            x: point.x.clamped(to: bounds.minX...bounds.maxX),
            y: point.y.clamped(to: bounds.minY...bounds.maxY)
        )
    }

    private func globalRect(fromLocalRect rect: CGRect) -> CGRect {
        CGRect(
            x: screenFrame.minX + rect.minX,
            y: screenFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}

private enum RegionCaptureMode {
    case selecting
    case annotating
}

private enum RegionSelectionInteraction {
    case idle
    case drawing(CGPoint)
    case moving(startSelection: CGRect)
    case movingAnnotation(id: UUID, startAnnotations: [RegionCaptureAnnotation])
    case resizing(handle: RegionResizeHandle, startSelection: CGRect)
    case annotating(start: CGPoint)
}

private enum RegionResizeHandle: String, CaseIterable, Identifiable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    var id: String { rawValue }

    var visualSize: CGFloat {
        switch self {
        case .top, .right, .bottom, .left:
            10
        case .topLeft, .topRight, .bottomRight, .bottomLeft:
            12
        }
    }

    var movesLeft: Bool {
        self == .topLeft || self == .left || self == .bottomLeft
    }

    var movesRight: Bool {
        self == .topRight || self == .right || self == .bottomRight
    }

    var movesTop: Bool {
        self == .topLeft || self == .top || self == .topRight
    }

    var movesBottom: Bool {
        self == .bottomLeft || self == .bottom || self == .bottomRight
    }

    func position(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft:
            CGPoint(x: rect.minX, y: rect.minY)
        case .top:
            CGPoint(x: rect.midX, y: rect.minY)
        case .topRight:
            CGPoint(x: rect.maxX, y: rect.minY)
        case .right:
            CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight:
            CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom:
            CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft:
            CGPoint(x: rect.minX, y: rect.maxY)
        case .left:
            CGPoint(x: rect.minX, y: rect.midY)
        }
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
