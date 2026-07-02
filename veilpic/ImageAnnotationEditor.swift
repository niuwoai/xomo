//
//  ImageAnnotationEditor.swift
//  veilpic
//
//  Created by Codex on 2026/6/30.
//

import AppKit
import SwiftUI

private enum ImageAnnotationTool: String, CaseIterable, Identifiable {
    case pen
    case rectangle
    case ellipse
    case arrow
    case text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pen:
            L10n.text("annotation.tool.pen")
        case .rectangle:
            L10n.text("annotation.tool.rectangle")
        case .ellipse:
            L10n.text("annotation.tool.ellipse")
        case .arrow:
            L10n.text("annotation.tool.arrow")
        case .text:
            L10n.text("annotation.tool.text")
        }
    }

    var symbolName: String {
        switch self {
        case .pen:
            "pencil.tip"
        case .rectangle:
            "rectangle"
        case .ellipse:
            "oval"
        case .arrow:
            "arrow.up.right"
        case .text:
            "textformat"
        }
    }
}

private struct ImageAnnotationItem: Identifiable {
    enum Kind {
        case pen([CGPoint])
        case rectangle(CGRect)
        case ellipse(CGRect)
        case arrow(CGPoint, CGPoint)
        case text(String, CGPoint)
    }

    let id = UUID()
    var kind: Kind
    var color: NSColor
    var lineWidth: CGFloat
    var fontSize: CGFloat
}

@MainActor
final class ImageAnnotationEditorPresenter: NSObject, NSWindowDelegate {
    static let shared = ImageAnnotationEditorPresenter()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func open(image: NSImage, sourceName: String, onApply: @escaping (NSImage) -> Void) {
        let rootView = ImageAnnotationEditorView(
            image: image,
            sourceName: sourceName,
            onApply: { [weak self] annotatedImage in
                onApply(annotatedImage)
                self?.close()
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )
        let hostingController = NSHostingController(rootView: rootView)

        if let window {
            window.contentViewController = hostingController
            show(window)
            return
        }

        let window = NSWindow(contentViewController: hostingController)
        window.title = L10n.text("annotation.window.title")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(NSSize(width: 980, height: 720))
        window.minSize = NSSize(width: 760, height: 560)
        WindowChrome.applySeaSalt(to: window)
        window.center()
        self.window = window
        show(window)
    }

    private func close() {
        window?.close()
    }

    private func show(_ window: NSWindow) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === window {
            window = nil
        }
    }
}

private struct ImageAnnotationEditorView: View {
    let image: NSImage
    let sourceName: String
    let onApply: (NSImage) -> Void
    let onCancel: () -> Void

    @State private var annotations: [ImageAnnotationItem] = []
    @State private var draftAnnotation: ImageAnnotationItem?
    @State private var selectedTool: ImageAnnotationTool = .pen
    @State private var selectedColor = Color.red
    @State private var lineWidth: CGFloat = 4
    @State private var fontSize: CGFloat = 24
    @State private var textInput = L10n.text("annotation.text.default")

    private let renderer = ImageAnnotationRenderer()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
                .overlay(AppTheme.hairline)
            annotationSurface
        }
        .frame(minWidth: 760, minHeight: 560)
        .themedWindowBackground()
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text("annotation.window.title"))
                    .font(.headline)
                Text(sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(width: 170, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(ImageAnnotationTool.allCases) { tool in
                    Button {
                        selectedTool = tool
                    } label: {
                        Image(systemName: tool.symbolName)
                            .font(.headline)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .help(tool.title)
                    .foregroundStyle(selectedTool == tool ? .white : AppTheme.accent)
                    .background(selectedTool == tool ? AppTheme.accent : AppTheme.controlFill)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            Divider()
                .frame(height: 26)

            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 32)

            HStack(spacing: 6) {
                Image(systemName: "lineweight")
                    .foregroundStyle(.secondary)
                Slider(value: $lineWidth, in: 1...12, step: 1)
                    .frame(width: 84)
                Text("\(Int(lineWidth))")
                    .font(.caption.monospacedDigit())
                    .frame(width: 20)
            }

            if selectedTool == .text {
                TextField(L10n.text("annotation.text.placeholder"), text: $textInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)

                Stepper(value: $fontSize, in: 12...56, step: 2) {
                    Text("\(Int(fontSize))")
                        .font(.caption.monospacedDigit())
                        .frame(width: 24)
                }
                .frame(width: 70)
            }

            Spacer()

            Button {
                undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .help(L10n.text("button.undo"))
            .disabled(annotations.isEmpty)

            Button {
                annotations.removeAll()
            } label: {
                Image(systemName: "trash")
            }
            .help(L10n.text("button.clear"))
            .disabled(annotations.isEmpty)

            Button(L10n.text("button.cancel"), action: onCancel)
                .keyboardShortcut(.escape)

            Button {
                onApply(renderer.render(image: image, annotations: annotations))
            } label: {
                Label(L10n.text("annotation.action.apply"), systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return)
        }
        .padding(14)
    }

    private var annotationSurface: some View {
        GeometryReader { proxy in
            let imageSize = normalizedImageSize
            let imageRect = imageSize.aspectFitRect(in: proxy.size, inset: 24)

            ZStack(alignment: .topLeading) {
                AppTheme.windowBackground

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.70))
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)
                    .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)

                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)

                Canvas { context, _ in
                    for annotation in annotations {
                        draw(annotation, in: &context, imageRect: imageRect, imageSize: imageSize)
                    }
                    if let draftAnnotation {
                        draw(draftAnnotation, in: &context, imageRect: imageRect, imageSize: imageSize)
                    }
                }
                .contentShape(Rectangle())
                .gesture(annotationGesture(imageRect: imageRect, imageSize: imageSize))

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppTheme.hairline, lineWidth: 1)
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)
                    .allowsHitTesting(false)
            }
        }
    }

    private var normalizedImageSize: CGSize {
        image.size == .zero ? CGSize(width: 1, height: 1) : image.size
    }

    private func annotationGesture(imageRect: CGRect, imageSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: selectedTool == .text ? 0 : 2)
            .onChanged { value in
                let start = imagePoint(from: value.startLocation, imageRect: imageRect, imageSize: imageSize)
                let current = imagePoint(from: value.location, imageRect: imageRect, imageSize: imageSize)
                draftAnnotation = annotation(for: selectedTool, start: start, current: current)
            }
            .onEnded { value in
                let start = imagePoint(from: value.startLocation, imageRect: imageRect, imageSize: imageSize)
                let current = imagePoint(from: value.location, imageRect: imageRect, imageSize: imageSize)
                if let annotation = annotation(for: selectedTool, start: start, current: current) {
                    annotations.append(annotation)
                }
                draftAnnotation = nil
            }
    }

    private func annotation(for tool: ImageAnnotationTool, start: CGPoint, current: CGPoint) -> ImageAnnotationItem? {
        let color = NSColor(selectedColor)
        switch tool {
        case .pen:
            let previousPoints: [CGPoint]
            if case let .pen(points)? = draftAnnotation?.kind {
                previousPoints = points
            } else {
                previousPoints = [start]
            }
            return ImageAnnotationItem(
                kind: .pen(previousPoints + [current]),
                color: color,
                lineWidth: lineWidth,
                fontSize: fontSize
            )
        case .rectangle:
            return ImageAnnotationItem(
                kind: .rectangle(CGRect.bounding(start, current).standardized),
                color: color,
                lineWidth: lineWidth,
                fontSize: fontSize
            )
        case .ellipse:
            return ImageAnnotationItem(
                kind: .ellipse(CGRect.bounding(start, current).standardized),
                color: color,
                lineWidth: lineWidth,
                fontSize: fontSize
            )
        case .arrow:
            return ImageAnnotationItem(
                kind: .arrow(start, current),
                color: color,
                lineWidth: lineWidth,
                fontSize: fontSize
            )
        case .text:
            let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return ImageAnnotationItem(
                kind: .text(trimmed, current),
                color: color,
                lineWidth: lineWidth,
                fontSize: fontSize
            )
        }
    }

    private func undo() {
        guard !annotations.isEmpty else { return }
        annotations.removeLast()
    }

    private func imagePoint(from point: CGPoint, imageRect: CGRect, imageSize: CGSize) -> CGPoint {
        let x = ((point.x - imageRect.minX) / imageRect.width * imageSize.width).clamped(to: 0...imageSize.width)
        let y = ((point.y - imageRect.minY) / imageRect.height * imageSize.height).clamped(to: 0...imageSize.height)
        return CGPoint(x: x, y: y)
    }

    private func viewPoint(from point: CGPoint, imageRect: CGRect, imageSize: CGSize) -> CGPoint {
        CGPoint(
            x: imageRect.minX + point.x / imageSize.width * imageRect.width,
            y: imageRect.minY + point.y / imageSize.height * imageRect.height
        )
    }

    private func viewRect(from rect: CGRect, imageRect: CGRect, imageSize: CGSize) -> CGRect {
        let origin = viewPoint(from: rect.origin, imageRect: imageRect, imageSize: imageSize)
        let maxPoint = viewPoint(from: CGPoint(x: rect.maxX, y: rect.maxY), imageRect: imageRect, imageSize: imageSize)
        return CGRect.bounding(origin, maxPoint).standardized
    }

    private func scaledLineWidth(_ width: CGFloat, imageRect: CGRect, imageSize: CGSize) -> CGFloat {
        width * min(imageRect.width / imageSize.width, imageRect.height / imageSize.height)
    }

    private func draw(_ annotation: ImageAnnotationItem, in context: inout GraphicsContext, imageRect: CGRect, imageSize: CGSize) {
        let color = Color(nsColor: annotation.color)
        let stroke = StrokeStyle(lineWidth: scaledLineWidth(annotation.lineWidth, imageRect: imageRect, imageSize: imageSize), lineCap: .round, lineJoin: .round)

        switch annotation.kind {
        case let .pen(points):
            guard let first = points.first else { return }
            let path = Path { path in
                path.move(to: viewPoint(from: first, imageRect: imageRect, imageSize: imageSize))
                for point in points.dropFirst() {
                    path.addLine(to: viewPoint(from: point, imageRect: imageRect, imageSize: imageSize))
                }
            }
            context.stroke(path, with: .color(color), style: stroke)
        case let .rectangle(rect):
            context.stroke(Path(viewRect(from: rect, imageRect: imageRect, imageSize: imageSize)), with: .color(color), style: stroke)
        case let .ellipse(rect):
            context.stroke(Path(ellipseIn: viewRect(from: rect, imageRect: imageRect, imageSize: imageSize)), with: .color(color), style: stroke)
        case let .arrow(start, end):
            let startPoint = viewPoint(from: start, imageRect: imageRect, imageSize: imageSize)
            let endPoint = viewPoint(from: end, imageRect: imageRect, imageSize: imageSize)
            context.stroke(arrowPath(from: startPoint, to: endPoint), with: .color(color), style: stroke)
        case let .text(text, point):
            let position = viewPoint(from: point, imageRect: imageRect, imageSize: imageSize)
            context.draw(
                Text(text)
                    .font(.system(size: scaledLineWidth(annotation.fontSize, imageRect: imageRect, imageSize: imageSize), weight: .semibold))
                    .foregroundStyle(color),
                at: position,
                anchor: .topLeading
            )
        }
    }

    private func arrowPath(from start: CGPoint, to end: CGPoint) -> Path {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)

            let angle = atan2(end.y - start.y, end.x - start.x)
            let headLength: CGFloat = 18
            let left = CGPoint(
                x: end.x - headLength * cos(angle - .pi / 6),
                y: end.y - headLength * sin(angle - .pi / 6)
            )
            let right = CGPoint(
                x: end.x - headLength * cos(angle + .pi / 6),
                y: end.y - headLength * sin(angle + .pi / 6)
            )
            path.move(to: left)
            path.addLine(to: end)
            path.addLine(to: right)
        }
    }
}

private final class ImageAnnotationRenderer {
    func render(image: NSImage, annotations: [ImageAnnotationItem]) -> NSImage {
        let size = image.size == .zero ? CGSize(width: 1, height: 1) : image.size
        let output = NSImage(size: size)

        output.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        for annotation in annotations {
            draw(annotation, in: size)
        }
        output.unlockFocus()

        return output
    }

    private func draw(_ annotation: ImageAnnotationItem, in imageSize: CGSize) {
        annotation.color.setStroke()
        annotation.color.setFill()

        switch annotation.kind {
        case let .pen(points):
            let path = NSBezierPath()
            path.lineWidth = annotation.lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            if let first = points.first {
                path.move(to: flipped(first, imageSize: imageSize))
                for point in points.dropFirst() {
                    path.line(to: flipped(point, imageSize: imageSize))
                }
            }
            path.stroke()
        case let .rectangle(rect):
            let path = NSBezierPath(rect: flipped(rect, imageSize: imageSize))
            path.lineWidth = annotation.lineWidth
            path.stroke()
        case let .ellipse(rect):
            let path = NSBezierPath(ovalIn: flipped(rect, imageSize: imageSize))
            path.lineWidth = annotation.lineWidth
            path.stroke()
        case let .arrow(start, end):
            drawArrow(from: flipped(start, imageSize: imageSize), to: flipped(end, imageSize: imageSize), annotation: annotation)
        case let .text(text, point):
            drawText(text, at: point, annotation: annotation, imageSize: imageSize)
        }
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, annotation: ImageAnnotationItem) {
        let path = NSBezierPath()
        path.lineWidth = annotation.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: start)
        path.line(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength = max(annotation.lineWidth * 4.2, 18)
        let left = CGPoint(
            x: end.x - headLength * cos(angle - .pi / 6),
            y: end.y - headLength * sin(angle - .pi / 6)
        )
        let right = CGPoint(
            x: end.x - headLength * cos(angle + .pi / 6),
            y: end.y - headLength * sin(angle + .pi / 6)
        )
        path.move(to: left)
        path.line(to: end)
        path.line(to: right)
        path.stroke()
    }

    private func drawText(_ text: String, at point: CGPoint, annotation: ImageAnnotationItem, imageSize: CGSize) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: annotation.fontSize, weight: .semibold),
            .foregroundColor: annotation.color
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        attributed.draw(at: CGPoint(x: point.x, y: imageSize.height - point.y - annotation.fontSize))
    }

    private func flipped(_ point: CGPoint, imageSize: CGSize) -> CGPoint {
        CGPoint(x: point.x, y: imageSize.height - point.y)
    }

    private func flipped(_ rect: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(x: rect.minX, y: imageSize.height - rect.maxY, width: rect.width, height: rect.height)
    }
}

private extension CGSize {
    func aspectFitRect(in container: CGSize, inset: CGFloat) -> CGRect {
        let available = CGSize(width: max(container.width - inset * 2, 1), height: max(container.height - inset * 2, 1))
        let scale = min(available.width / width, available.height / height)
        let fitted = CGSize(width: width * scale, height: height * scale)
        return CGRect(
            x: (container.width - fitted.width) / 2,
            y: (container.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
    }
}

private extension CGRect {
    static func bounding(_ first: CGPoint, _ second: CGPoint) -> CGRect {
        CGRect(
            x: min(first.x, second.x),
            y: min(first.y, second.y),
            width: abs(second.x - first.x),
            height: abs(second.y - first.y)
        )
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
