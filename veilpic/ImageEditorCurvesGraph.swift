import SwiftUI

enum ImageEditorCurvesAnchor: String, CaseIterable, Identifiable {
    case shadows
    case midtones
    case highlights

    var id: String { rawValue }

    var input: Double {
        switch self {
        case .shadows: 0.25
        case .midtones: 0.5
        case .highlights: 0.75
        }
    }

    var gain: Double {
        switch self {
        case .shadows, .highlights: 0.25
        case .midtones: 0.35
        }
    }
}

enum ImageEditorCurvesMapping {
    static func output(
        for anchor: ImageEditorCurvesAnchor,
        shadows: Double,
        midtones: Double,
        highlights: Double
    ) -> Double {
        let value: Double
        switch anchor {
        case .shadows: value = shadows
        case .midtones: value = midtones
        case .highlights: value = highlights
        }
        return min(1, max(0, anchor.input + min(1, max(-1, value)) * anchor.gain))
    }

    static func adjustmentValue(for anchor: ImageEditorCurvesAnchor, output: Double) -> Double {
        min(1, max(-1, (min(1, max(0, output)) - anchor.input) / anchor.gain))
    }

    static func points(shadows: Double, midtones: Double, highlights: Double) -> [(Double, Double)] {
        [
            (0, 0),
            (ImageEditorCurvesAnchor.shadows.input, output(
                for: .shadows, shadows: shadows, midtones: midtones, highlights: highlights
            )),
            (ImageEditorCurvesAnchor.midtones.input, output(
                for: .midtones, shadows: shadows, midtones: midtones, highlights: highlights
            )),
            (ImageEditorCurvesAnchor.highlights.input, output(
                for: .highlights, shadows: shadows, midtones: midtones, highlights: highlights
            )),
            (1, 1)
        ]
    }

    static func map(_ value: Double, points: [(Double, Double)]) -> Double {
        let input = min(1, max(0, value))
        guard points.count > 1 else { return input }
        let slopes = zip(points, points.dropFirst()).map { pair in
            (pair.1.1 - pair.0.1) / max(0.001, pair.1.0 - pair.0.0)
        }
        var tangents = [Double](repeating: 0, count: points.count)
        tangents[0] = slopes[0]
        tangents[points.count - 1] = slopes[slopes.count - 1]
        if points.count > 2 {
            for index in 1..<(points.count - 1) {
                let previous = slopes[index - 1]
                let next = slopes[index]
                guard previous * next > 0 else { continue }
                let previousWidth = points[index].0 - points[index - 1].0
                let nextWidth = points[index + 1].0 - points[index].0
                let previousWeight = 2 * nextWidth + previousWidth
                let nextWeight = nextWidth + 2 * previousWidth
                tangents[index] = (previousWeight + nextWeight)
                    / (previousWeight / previous + nextWeight / next)
            }
        }

        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            guard input >= start.0 && input <= end.0 else { continue }
            let span = max(0.001, end.0 - start.0)
            let t = min(1, max(0, (input - start.0) / span))
            let tSquared = t * t
            let tCubed = tSquared * t
            let startWeight = 2 * tCubed - 3 * tSquared + 1
            let startTangentWeight = tCubed - 2 * tSquared + t
            let endWeight = -2 * tCubed + 3 * tSquared
            let endTangentWeight = tCubed - tSquared
            return startWeight * start.1
                + startTangentWeight * span * tangents[index]
                + endWeight * end.1
                + endTangentWeight * span * tangents[index + 1]
        }
        return input
    }
}

struct ImageEditorCurvesGraph: View {
    let summary: ImageEditorHistogramSummary
    let histogramChannel: ImageEditorHistogramChannel
    let channel: ImageEditorLevelsChannel
    @Binding var shadows: Double
    @Binding var midtones: Double
    @Binding var highlights: Double

    @State private var dragOrigin: (anchor: ImageEditorCurvesAnchor, value: Double)?

    var body: some View {
        GeometryReader { geometry in
            let plot = CGRect(x: 10, y: 8, width: max(1, geometry.size.width - 20), height: max(1, geometry.size.height - 16))
            ZStack {
                Canvas { context, size in
                    drawGrid(in: &context, plot: plot)
                    drawHistogram(in: &context, plot: plot)
                    drawCurve(in: &context, plot: plot)
                }

                ForEach(ImageEditorCurvesAnchor.allCases) { anchor in
                    let output = output(for: anchor)
                    Circle()
                        .fill(Color.clear)
                        .overlay {
                            Circle()
                                .fill(Color(nsColor: ImageEditorTheme.panel))
                                .overlay(Circle().stroke(curveColor, lineWidth: 2))
                                .frame(width: 13, height: 13)
                        }
                        .frame(width: 24, height: 24)
                        .position(point(for: anchor, output: output, in: plot))
                        .contentShape(Circle())
                        .gesture(dragGesture(for: anchor, plotHeight: plot.height))
                        .accessibilityElement()
                        .accessibilityLabel(L10n.text("imageEditor.curves.\(anchor.rawValue)"))
                        .accessibilityValue("\(Int((output * 100).rounded()))")
                        .accessibilityAdjustableAction { direction in
                            let step = direction == .increment ? 0.05 : -0.05
                            setValue(for: anchor, to: value(for: anchor) + step)
                        }
                        .accessibilityIdentifier("image-editor-curves-anchor-\(anchor.rawValue)")
                }
            }
            .background(Color.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L10n.text("imageEditor.curves.graph"))
            .accessibilityIdentifier("image-editor-curves-graph")
        }
        .frame(height: 122)
    }

    private var curveColor: Color {
        switch channel {
        case .rgb: .white
        case .red: .red
        case .green: .green
        case .blue: .blue
        }
    }

    private func drawGrid(in context: inout GraphicsContext, plot: CGRect) {
        var grid = Path()
        for division in 0...4 {
            let fraction = CGFloat(division) / 4
            let x = plot.minX + plot.width * fraction
            let y = plot.minY + plot.height * fraction
            grid.move(to: CGPoint(x: x, y: plot.minY))
            grid.addLine(to: CGPoint(x: x, y: plot.maxY))
            grid.move(to: CGPoint(x: plot.minX, y: y))
            grid.addLine(to: CGPoint(x: plot.maxX, y: y))
        }
        context.stroke(grid, with: .color(.white.opacity(0.14)), lineWidth: 0.5)
    }

    private func drawHistogram(in context: inout GraphicsContext, plot: CGRect) {
        guard !summary.bins.isEmpty else { return }
        let width = plot.width / CGFloat(summary.bins.count)
        var bars = Path()
        for bin in summary.bins {
            let height = plot.height * CGFloat(max(0, histogramChannel.value(in: bin)))
            bars.addRect(CGRect(
                x: plot.minX + CGFloat(bin.index) * width,
                y: plot.maxY - height,
                width: max(1, width - 0.5),
                height: height
            ))
        }
        context.fill(bars, with: .color(curveColor.opacity(0.24)))
    }

    private func drawCurve(in context: inout GraphicsContext, plot: CGRect) {
        let points = ImageEditorCurvesMapping.points(shadows: shadows, midtones: midtones, highlights: highlights)
        var path = Path()
        for step in 0...96 {
            let input = Double(step) / 96
            let mapped = ImageEditorCurvesMapping.map(input, points: points)
            let point = CGPoint(x: plot.minX + plot.width * input, y: plot.maxY - plot.height * mapped)
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        context.stroke(path, with: .color(curveColor), lineWidth: 2)
    }

    private func dragGesture(for anchor: ImageEditorCurvesAnchor, plotHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                if dragOrigin?.anchor != anchor {
                    dragOrigin = (anchor, self.value(for: anchor))
                }
                guard let origin = dragOrigin, origin.anchor == anchor else { return }
                let startingOutput = ImageEditorCurvesMapping.output(
                    for: anchor,
                    shadows: anchor == .shadows ? origin.value : shadows,
                    midtones: anchor == .midtones ? origin.value : midtones,
                    highlights: anchor == .highlights ? origin.value : highlights
                )
                let output = startingOutput - Double(drag.translation.height / max(1, plotHeight))
                setValue(for: anchor, to: ImageEditorCurvesMapping.adjustmentValue(for: anchor, output: output))
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private func point(for anchor: ImageEditorCurvesAnchor, output: Double, in plot: CGRect) -> CGPoint {
        CGPoint(x: plot.minX + plot.width * anchor.input, y: plot.maxY - plot.height * output)
    }

    private func output(for anchor: ImageEditorCurvesAnchor) -> Double {
        ImageEditorCurvesMapping.output(for: anchor, shadows: shadows, midtones: midtones, highlights: highlights)
    }

    private func value(for anchor: ImageEditorCurvesAnchor) -> Double {
        switch anchor {
        case .shadows: shadows
        case .midtones: midtones
        case .highlights: highlights
        }
    }

    private func setValue(for anchor: ImageEditorCurvesAnchor, to value: Double) {
        switch anchor {
        case .shadows: shadows = min(1, max(-1, value))
        case .midtones: midtones = min(1, max(-1, value))
        case .highlights: highlights = min(1, max(-1, value))
        }
    }
}
