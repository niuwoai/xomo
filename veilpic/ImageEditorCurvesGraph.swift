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

    static func points(
        shadows: Double,
        midtones: Double,
        highlights: Double,
        customPoints: [ImageEditorCurveControlPoint] = []
    ) -> [(Double, Double)] {
        let legacyPoints: [(Double, Double)] = [
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
        let editablePoints = ImageEditorCurveControlPointRules.normalized(customPoints)
            .map { ($0.input, $0.output) }
        return (legacyPoints + editablePoints).sorted { $0.0 < $1.0 }
    }

    static func addingControlPoint(
        input: Double,
        output: Double,
        to points: [ImageEditorCurveControlPoint]
    ) -> [ImageEditorCurveControlPoint]? {
        let normalized = ImageEditorCurveControlPointRules.normalized(points)
        guard normalized.count < ImageEditorCurveControlPointRules.maximumCount,
              input.isFinite, output.isFinite else { return nil }
        let candidate = ImageEditorCurveControlPoint(
            input: min(ImageEditorCurveControlPointRules.maximumInput,
                       max(ImageEditorCurveControlPointRules.minimumInput, input)),
            output: min(1, max(0, output))
        )
        let combined = ImageEditorCurveControlPointRules.normalized(normalized + [candidate])
        guard combined.contains(where: { $0.id == candidate.id }) else { return nil }
        return combined
    }

    static func movingControlPoint(
        id: UUID,
        input: Double,
        output: Double,
        in points: [ImageEditorCurveControlPoint]
    ) -> [ImageEditorCurveControlPoint] {
        let normalized = ImageEditorCurveControlPointRules.normalized(points)
        guard input.isFinite, output.isFinite,
              let movingIndex = normalized.firstIndex(where: { $0.id == id }) else { return normalized }
        let movingPoint = normalized[movingIndex]
        let otherPoints = normalized.filter { $0.id != id }
        let boundaries = ImageEditorCurveControlPointRules.reservedInputs
            + otherPoints.map(\.input)
        let lowerBoundary = boundaries.filter { $0 < movingPoint.input }.max()
            ?? ImageEditorCurveControlPointRules.minimumInput
        let upperBoundary = boundaries.filter { $0 > movingPoint.input }.min()
            ?? ImageEditorCurveControlPointRules.maximumInput
        let minimumInput = max(
            ImageEditorCurveControlPointRules.minimumInput,
            lowerBoundary + ImageEditorCurveControlPointRules.minimumSpacing
        )
        let maximumInput = min(
            ImageEditorCurveControlPointRules.maximumInput,
            upperBoundary - ImageEditorCurveControlPointRules.minimumSpacing
        )
        var movedPoints = normalized
        movedPoints[movingIndex] = ImageEditorCurveControlPoint(
            id: id,
            input: min(maximumInput, max(minimumInput, input)),
            output: min(1, max(0, output))
        )
        return movedPoints.sorted { $0.input < $1.input }
    }

    static func removingControlPoint(
        id: UUID,
        from points: [ImageEditorCurveControlPoint]
    ) -> [ImageEditorCurveControlPoint] {
        ImageEditorCurveControlPointRules.normalized(points).filter { $0.id != id }
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
    @Binding var customPoints: [ImageEditorCurveControlPoint]

    @State private var dragOrigin: (anchor: ImageEditorCurvesAnchor, value: Double)?
    @State private var customDragOrigin: (id: UUID, input: Double, output: Double)?

    var body: some View {
        GeometryReader { geometry in
            let plot = CGRect(x: 10, y: 8, width: max(1, geometry.size.width - 20), height: max(1, geometry.size.height - 16))
            ZStack {
                Canvas { context, size in
                    drawGrid(in: &context, plot: plot)
                    drawHistogram(in: &context, plot: plot)
                    drawCurve(in: &context, plot: plot)
                }
                .contentShape(Rectangle())
                .gesture(addPointGesture(in: plot))

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

                ForEach(customPoints) { controlPoint in
                    Circle()
                        .fill(Color(nsColor: ImageEditorTheme.panel))
                        .overlay(Circle().stroke(curveColor, lineWidth: 2))
                        .frame(width: 13, height: 13)
                        .frame(width: 24, height: 24)
                        .position(point(for: controlPoint, in: plot))
                        .contentShape(Circle())
                        .gesture(customPointDragGesture(for: controlPoint, plot: plot))
                        .onTapGesture(count: 2) {
                            customPoints = ImageEditorCurvesMapping.removingControlPoint(
                                id: controlPoint.id,
                                from: customPoints
                            )
                        }
                        .accessibilityElement()
                        .accessibilityLabel(L10n.text("imageEditor.curves.customPoint"))
                        .accessibilityValue(L10n.format(
                            "imageEditor.curves.customPointValue",
                            Int((controlPoint.input * 100).rounded()),
                            Int((controlPoint.output * 100).rounded())
                        ))
                        .accessibilityHint(L10n.text("imageEditor.curves.customPointHint"))
                        .accessibilityAdjustableAction { direction in
                            let step = direction == .increment ? 0.05 : -0.05
                            customPoints = ImageEditorCurvesMapping.movingControlPoint(
                                id: controlPoint.id,
                                input: controlPoint.input,
                                output: controlPoint.output + step,
                                in: customPoints
                            )
                        }
                        .accessibilityAction(named: Text(L10n.text("imageEditor.curves.removePoint"))) {
                            customPoints = ImageEditorCurvesMapping.removingControlPoint(
                                id: controlPoint.id,
                                from: customPoints
                            )
                        }
                        .accessibilityIdentifier("image-editor-curves-custom-point-\(controlPoint.id.uuidString)")
                }
            }
            .background(Color.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L10n.text("imageEditor.curves.graph"))
            .accessibilityHint(L10n.text("imageEditor.curves.graphHint"))
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
        let points = ImageEditorCurvesMapping.points(
            shadows: shadows,
            midtones: midtones,
            highlights: highlights,
            customPoints: customPoints
        )
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

    private func addPointGesture(in plot: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { drag in
                guard abs(drag.translation.width) + abs(drag.translation.height) < 6 else { return }
                guard !isOverControlPoint(at: drag.startLocation, in: plot) else { return }
                addControlPoint(at: drag.startLocation, in: plot)
            }
    }

    private func isOverControlPoint(at location: CGPoint, in plot: CGRect) -> Bool {
        let customHandles = customPoints.map { point(for: $0, in: plot) }
        let fixedHandles = ImageEditorCurvesAnchor.allCases.map { anchor in
            point(for: anchor, output: output(for: anchor), in: plot)
        }
        return (customHandles + fixedHandles).contains {
            hypot($0.x - location.x, $0.y - location.y) <= 14
        }
    }

    private func addControlPoint(at location: CGPoint, in plot: CGRect) {
        guard plot.contains(location) else { return }
        let input = Double((location.x - plot.minX) / plot.width)
        let curvePoints = ImageEditorCurvesMapping.points(
            shadows: shadows,
            midtones: midtones,
            highlights: highlights,
            customPoints: customPoints
        )
        let output = ImageEditorCurvesMapping.map(input, points: curvePoints)
        let curveY = plot.maxY - plot.height * output
        guard abs(location.y - curveY) <= 14,
              let updated = ImageEditorCurvesMapping.addingControlPoint(
                input: input,
                output: output,
                to: customPoints
              ) else { return }
        customPoints = updated
    }

    private func customPointDragGesture(
        for controlPoint: ImageEditorCurveControlPoint,
        plot: CGRect
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                if customDragOrigin?.id != controlPoint.id {
                    customDragOrigin = (controlPoint.id, controlPoint.input, controlPoint.output)
                }
                guard let origin = customDragOrigin, origin.id == controlPoint.id else { return }
                customPoints = ImageEditorCurvesMapping.movingControlPoint(
                    id: controlPoint.id,
                    input: origin.input + Double(drag.translation.width / max(1, plot.width)),
                    output: origin.output - Double(drag.translation.height / max(1, plot.height)),
                    in: customPoints
                )
            }
            .onEnded { _ in customDragOrigin = nil }
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

    private func point(for controlPoint: ImageEditorCurveControlPoint, in plot: CGRect) -> CGPoint {
        CGPoint(
            x: plot.minX + plot.width * controlPoint.input,
            y: plot.maxY - plot.height * controlPoint.output
        )
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
