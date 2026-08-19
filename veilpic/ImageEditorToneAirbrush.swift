//
//  ImageEditorToneAirbrush.swift
//  veilpic
//
//  Created by Codex on 2026/7/19.
//

import AppKit
import Foundation
import SwiftUI

/// Captures deterministic airbrush dwell samples without repainting the full
/// layer for every pointer event. The canvas can preview the buildup cheaply,
/// then commit the collected pulse points as one undoable pixel operation.
struct ImageEditorToneAirbrushStroke: Equatable {
    static let pulseInterval: TimeInterval = 0.12
    static let maximumPulseCount = 80
    static let pulseFlow: CGFloat = 0.18

    private(set) var beganAt: TimeInterval?
    private(set) var currentPoint: CGPoint?
    private(set) var currentPressure: CGFloat?
    private(set) var currentDwellBeganAt: TimeInterval?
    private(set) var pulseSamples: [ImageEditorBrushStrokeSample] = []

    var pulsePoints: [CGPoint] { pulseSamples.map(\.point) }

    private var previousPoint: CGPoint?
    private var previousPressure: CGFloat?
    private var previousTime: TimeInterval?
    private var nextPulseTime: TimeInterval?

    var isActive: Bool { beganAt != nil }

    mutating func begin(at point: CGPoint, pressure: CGFloat? = nil, time: TimeInterval) {
        let safeTime = time.isFinite ? time : 0
        beganAt = safeTime
        currentPoint = point
        currentPressure = pressure
        currentDwellBeganAt = safeTime
        previousPoint = point
        previousPressure = pressure
        previousTime = safeTime
        nextPulseTime = safeTime + Self.pulseInterval
        pulseSamples = []
    }

    mutating func update(to point: CGPoint, pressure: CGFloat? = nil, time: TimeInterval) {
        guard let previousPoint,
              let previousTime,
              var nextPulseTime
        else {
            begin(at: point, pressure: pressure, time: time)
            return
        }

        let safeTime = max(previousTime, time.isFinite ? time : previousTime)
        let duration = safeTime - previousTime
        while nextPulseTime <= safeTime,
              pulseSamples.count < Self.maximumPulseCount {
            let progress = duration > 0
                ? max(0, min(1, (nextPulseTime - previousTime) / duration))
                : 1
            pulseSamples.append(ImageEditorBrushStrokeSample(
                point: CGPoint(
                    x: previousPoint.x + (point.x - previousPoint.x) * progress,
                    y: previousPoint.y + (point.y - previousPoint.y) * progress
                ),
                pressure: interpolatedPressure(
                    from: previousPressure,
                    to: pressure,
                    progress: progress
                )
            ))
            nextPulseTime += Self.pulseInterval
        }

        if hypot(point.x - previousPoint.x, point.y - previousPoint.y) > 0.5 {
            currentDwellBeganAt = safeTime
        }
        currentPoint = point
        currentPressure = pressure ?? previousPressure
        self.previousPoint = point
        self.previousPressure = pressure ?? previousPressure
        self.previousTime = safeTime
        self.nextPulseTime = nextPulseTime
    }

    mutating func finish(at point: CGPoint, time: TimeInterval) -> [CGPoint] {
        update(to: point, pressure: currentPressure, time: time)
        return pulsePoints
    }

    mutating func finishSamples(
        at point: CGPoint,
        pressure: CGFloat? = nil,
        time: TimeInterval
    ) -> [ImageEditorBrushStrokeSample] {
        update(to: point, pressure: pressure ?? currentPressure, time: time)
        return pulseSamples
    }

    mutating func reset() {
        self = ImageEditorToneAirbrushStroke()
    }

    static func previewPulseCount(elapsed: TimeInterval) -> Int {
        guard elapsed.isFinite, elapsed > 0 else { return 0 }
        return min(maximumPulseCount, Int(elapsed / pulseInterval))
    }

    static func previewOpacity(exposure: CGFloat, elapsed: TimeInterval) -> CGFloat {
        let pulses = previewPulseCount(elapsed: elapsed)
        guard pulses > 0 else { return 0.035 }
        let perPulse = max(0, min(1, exposure)) * pulseFlow
        let accumulated = 1 - pow(1 - perPulse, CGFloat(pulses))
        return min(0.24, 0.035 + accumulated * 0.205)
    }

    static func paintPreviewOpacity(
        opacity: CGFloat,
        flow: CGFloat,
        elapsed: TimeInterval
    ) -> CGFloat {
        let pulses = previewPulseCount(elapsed: elapsed)
        guard pulses > 0 else { return 0.035 }
        let normalizedFlow = max(0, min(1, flow))
        let normalizedOpacity = max(0, min(1, opacity))
        let accumulated = min(
            normalizedOpacity,
            1 - pow(1 - normalizedFlow, CGFloat(pulses))
        )
        return min(0.32, 0.035 + accumulated * 0.285)
    }

    private func interpolatedPressure(
        from start: CGFloat?,
        to end: CGFloat?,
        progress: CGFloat
    ) -> CGFloat? {
        switch (start, end) {
        case let (.some(start), .some(end)):
            return start + (end - start) * progress
        case let (.some(start), .none):
            return start
        case let (.none, .some(end)):
            return end
        case (.none, .none):
            return nil
        }
    }
}

struct ImageEditorPaintAirbrushPreview: View {
    let color: NSColor
    let point: CGPoint
    let dwellBeganAt: TimeInterval
    let opacity: CGFloat
    let flow: CGFloat
    let diameter: CGFloat
    let roundness: CGFloat
    let angleDegrees: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 15.0)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate - dwellBeganAt
            let previewOpacity = ImageEditorToneAirbrushStroke.paintPreviewOpacity(
                opacity: opacity,
                flow: flow,
                elapsed: elapsed
            )
            Ellipse()
                .fill(Color(nsColor: color).opacity(previewOpacity))
                .overlay {
                    Ellipse()
                        .stroke(
                            Color.gray.opacity(0.68),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )
                }
                .frame(
                    width: diameter,
                    height: diameter * max(0.1, min(1, roundness))
                )
                .rotationEffect(.degrees(Double(angleDegrees)))
                .position(point)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

struct ImageEditorToneAirbrushPreview: View {
    let isBurn: Bool
    let point: CGPoint
    let dwellBeganAt: TimeInterval
    let exposure: CGFloat
    let diameter: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 15.0)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate - dwellBeganAt
            let opacity = ImageEditorToneAirbrushStroke.previewOpacity(
                exposure: exposure,
                elapsed: elapsed
            )
            Circle()
                .fill(isBurn ? Color.black.opacity(opacity) : Color.white.opacity(opacity))
                .overlay {
                    Circle()
                        .stroke(
                            Color.gray.opacity(0.68),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )
                }
                .frame(width: diameter, height: diameter)
                .position(point)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
