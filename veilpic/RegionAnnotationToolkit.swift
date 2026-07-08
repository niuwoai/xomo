//
//  RegionAnnotationToolkit.swift
//  veilpic
//
//  Created by Codex on 2026/7/6.
//

import AppKit
import SwiftUI

enum RegionAnnotationTool: String, CaseIterable, Identifiable {
    case move
    case rectangle
    case ellipse
    case brush
    case text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .move:
            L10n.text("captureToolbar.tool.move")
        case .rectangle:
            L10n.text("annotation.tool.rectangle")
        case .ellipse:
            L10n.text("annotation.tool.ellipse")
        case .brush:
            L10n.text("annotation.tool.pen")
        case .text:
            L10n.text("annotation.tool.text")
        }
    }

    var symbolName: String {
        switch self {
        case .move:
            "hand.draw"
        case .rectangle:
            "rectangle"
        case .ellipse:
            "circle"
        case .brush:
            "pencil"
        case .text:
            "textformat"
        }
    }
}

struct RegionCaptureAnnotation: Identifiable {
    enum Kind {
        case rectangle(CGRect)
        case ellipse(CGRect)
        case brush([CGPoint])
        case text(String, CGRect)
    }

    let id: UUID
    var kind: Kind
    var strokeColor: NSColor
    var fillColor: NSColor?
    var lineWidth: CGFloat
    var fontSize: CGFloat

    init(
        id: UUID = UUID(),
        kind: Kind,
        strokeColor: NSColor,
        fillColor: NSColor?,
        lineWidth: CGFloat,
        fontSize: CGFloat
    ) {
        self.id = id
        self.kind = kind
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.lineWidth = lineWidth
        self.fontSize = fontSize
    }
}

struct RegionAnnotationColor: Identifiable {
    let nameKey: String
    let color: NSColor

    var id: String { nameKey }

    static let swatches: [RegionAnnotationColor] = [
        RegionAnnotationColor(nameKey: "captureToolbar.color.red", color: .systemRed),
        RegionAnnotationColor(nameKey: "captureToolbar.color.blue", color: .systemBlue),
        RegionAnnotationColor(nameKey: "captureToolbar.color.green", color: .systemGreen),
        RegionAnnotationColor(nameKey: "captureToolbar.color.yellow", color: .systemYellow),
        RegionAnnotationColor(nameKey: "captureToolbar.color.orange", color: .systemOrange),
        RegionAnnotationColor(nameKey: "captureToolbar.color.purple", color: .systemPurple),
        RegionAnnotationColor(nameKey: "captureToolbar.color.pink", color: .systemPink),
        RegionAnnotationColor(nameKey: "captureToolbar.color.black", color: .black)
    ]
}

struct RegionAnnotationToolbarView: View {
    @Binding var selectedTool: RegionAnnotationTool
    @Binding var strokeColor: NSColor
    @Binding var fillColor: NSColor?
    @Binding var lineWidth: CGFloat
    @Binding var fontSize: CGFloat

    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onCopy: (@escaping (Bool) -> Void) -> Void
    let onSave: () -> Void
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var toastMessage: String?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                toolSection
                divider
                colorSection
                divider
                lineWidthSection
                if selectedTool == .text {
                    divider
                    fontSizeSection
                }
                divider
                undoRedoSection
                divider
                actionSection
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.72))
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
            )

            if let toastMessage {
                Text(toastMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: toastMessage)
    }

    private var toolSection: some View {
        HStack(spacing: 4) {
            ForEach(RegionAnnotationTool.allCases) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tool.symbolName)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(height: 16)
                        Text(tool.title)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                    .frame(width: 42, height: 36)
                    .background(selectedTool == tool ? Color.white.opacity(0.22) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(tool.title)
            }
        }
    }

    private var colorSection: some View {
        HStack(spacing: 8) {
            colorSwatches(
                title: L10n.text("captureToolbar.stroke"),
                selectedColor: strokeColor,
                includeClear: false
            ) { color in
                if let color {
                    strokeColor = color
                }
            }

            colorSwatches(
                title: L10n.text("captureToolbar.fill"),
                selectedColor: fillColor,
                includeClear: true
            ) { color in
                fillColor = color
            }
        }
    }

    private func colorSwatches(
        title: String,
        selectedColor: NSColor?,
        includeClear: Bool,
        onSelect: @escaping (NSColor?) -> Void
    ) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))

            if includeClear {
                Button {
                    onSelect(nil)
                } label: {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
                        .frame(width: 14, height: 14)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(selectedColor == nil ? Color.white.opacity(0.26) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(L10n.text("captureToolbar.fill.clear"))
            }

            ForEach(RegionAnnotationColor.swatches) { swatch in
                Button {
                    onSelect(swatch.color)
                } label: {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(nsColor: swatch.color))
                        .frame(width: 14, height: 14)
                        .overlay {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(isSameColor(selectedColor, swatch.color) ? Color.white : Color.clear, lineWidth: 1.6)
                        }
                }
                .buttonStyle(.plain)
                .help(L10n.text(swatch.nameKey))
            }
        }
    }

    private var lineWidthSection: some View {
        HStack(spacing: 6) {
            Text(L10n.text("captureToolbar.thickness"))
                .font(.system(size: 10, weight: .medium))

            Slider(value: $lineWidth, in: 1...12, step: 1)
                .frame(width: 70)

            Text("\(Int(lineWidth))")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .frame(width: 16)
        }
    }

    private var fontSizeSection: some View {
        HStack(spacing: 6) {
            Text(L10n.text("captureToolbar.fontSize"))
                .font(.system(size: 10, weight: .medium))

            Slider(value: $fontSize, in: 10...72, step: 2)
                .frame(width: 60)

            Text("\(Int(fontSize))")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .frame(width: 20)
        }
    }

    private var undoRedoSection: some View {
        HStack(spacing: 6) {
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(!canUndo)
            .help(L10n.text("button.undo"))

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(!canRedo)
            .help(L10n.text("button.redo"))
        }
    }

    private var actionSection: some View {
        HStack(spacing: 8) {
            Button {
                onCopy { success in
                    showToast(success ? L10n.text("captureToolbar.toast.copied") : L10n.text("captureToolbar.toast.copyFailed"))
                }
            } label: {
                Label(L10n.text("button.copy"), systemImage: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)

            Button(action: onSave) {
                Label(L10n.text("button.save"), systemImage: "square.and.arrow.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)

            Button(action: onComplete) {
                Label(L10n.text("button.done"), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help(L10n.text("button.cancel"))
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.25))
            .frame(width: 1, height: 22)
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    private func isSameColor(_ lhs: NSColor?, _ rhs: NSColor) -> Bool {
        guard let lhs else { return false }
        guard let leftRGB = lhs.usingColorSpace(.sRGB),
              let rightRGB = rhs.usingColorSpace(.sRGB)
        else {
            return lhs == rhs
        }

        return abs(leftRGB.redComponent - rightRGB.redComponent) < 0.01 &&
            abs(leftRGB.greenComponent - rightRGB.greenComponent) < 0.01 &&
            abs(leftRGB.blueComponent - rightRGB.blueComponent) < 0.01 &&
            abs(leftRGB.alphaComponent - rightRGB.alphaComponent) < 0.01
    }
}

struct RegionAnnotationRenderer {
    func render(baseImage: NSImage, selection: CGRect, annotations: [RegionCaptureAnnotation]) -> NSImage {
        let outputSize = normalizedSize(baseImage, fallback: selection.size)
        let output = NSImage(size: outputSize)

        output.lockFocus()
        baseImage.draw(in: CGRect(origin: .zero, size: outputSize))

        for annotation in annotations {
            draw(annotation, selectionOrigin: selection.origin, imageSize: outputSize)
        }

        output.unlockFocus()
        return output
    }

    private func draw(_ annotation: RegionCaptureAnnotation, selectionOrigin: CGPoint, imageSize: CGSize) {
        annotation.strokeColor.setStroke()
        annotation.fillColor?.setFill()

        switch annotation.kind {
        case let .rectangle(rect):
            let path = NSBezierPath(rect: flipped(local(rect, selectionOrigin: selectionOrigin), imageSize: imageSize))
            path.lineWidth = annotation.lineWidth
            annotation.fillColor.map { _ in path.fill() }
            path.stroke()
        case let .ellipse(rect):
            let path = NSBezierPath(ovalIn: flipped(local(rect, selectionOrigin: selectionOrigin), imageSize: imageSize))
            path.lineWidth = annotation.lineWidth
            annotation.fillColor.map { _ in path.fill() }
            path.stroke()
        case let .brush(points):
            drawBrush(points, annotation: annotation, selectionOrigin: selectionOrigin, imageSize: imageSize)
        case let .text(text, rect):
            drawText(text, rect: rect, annotation: annotation, selectionOrigin: selectionOrigin, imageSize: imageSize)
        }
    }

    private func drawBrush(
        _ points: [CGPoint],
        annotation: RegionCaptureAnnotation,
        selectionOrigin: CGPoint,
        imageSize: CGSize
    ) {
        guard let first = points.first else { return }
        let path = NSBezierPath()
        path.move(to: flipped(local(first, selectionOrigin: selectionOrigin), imageSize: imageSize))
        for point in points.dropFirst() {
            path.line(to: flipped(local(point, selectionOrigin: selectionOrigin), imageSize: imageSize))
        }
        path.lineWidth = annotation.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private func drawText(
        _ text: String,
        rect: CGRect,
        annotation: RegionCaptureAnnotation,
        selectionOrigin: CGPoint,
        imageSize: CGSize
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let localRect = local(rect, selectionOrigin: selectionOrigin)
        let drawRect = CGRect(
            x: localRect.minX,
            y: imageSize.height - localRect.maxY,
            width: max(localRect.width, 8),
            height: max(localRect.height, annotation.fontSize + 8)
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: annotation.fontSize, weight: .semibold),
            .foregroundColor: annotation.strokeColor
        ]
        NSAttributedString(string: trimmed, attributes: attributes).draw(in: drawRect)
    }

    private func local(_ rect: CGRect, selectionOrigin: CGPoint) -> CGRect {
        rect.offsetBy(dx: -selectionOrigin.x, dy: -selectionOrigin.y)
    }

    private func local(_ point: CGPoint, selectionOrigin: CGPoint) -> CGPoint {
        CGPoint(x: point.x - selectionOrigin.x, y: point.y - selectionOrigin.y)
    }

    private func flipped(_ rect: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(x: rect.minX, y: imageSize.height - rect.maxY, width: rect.width, height: rect.height)
    }

    private func flipped(_ point: CGPoint, imageSize: CGSize) -> CGPoint {
        CGPoint(x: point.x, y: imageSize.height - point.y)
    }

    private func normalizedSize(_ image: NSImage, fallback: CGSize) -> CGSize {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return fallback }
        return size
    }
}
