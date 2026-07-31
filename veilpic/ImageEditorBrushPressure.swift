//
//  ImageEditorBrushPressure.swift
//  veilpic
//
//  Created by Codex on 2026/7/12.
//

import AppKit

enum ImageEditorBrushPressureInput {
    static func pressure(from event: NSEvent?) -> CGFloat? {
        guard let event else { return nil }
        let supportsPressure = event.type == .tabletPoint
            || event.subtype == .tabletPoint
            || event.type == .pressure
        return normalizedPressure(
            rawPressure: CGFloat(event.pressure),
            supportsPressure: supportsPressure
        )
    }

    static func normalizedPressure(
        rawPressure: CGFloat,
        supportsPressure: Bool
    ) -> CGFloat? {
        guard supportsPressure else { return nil }
        return max(0, min(1, rawPressure))
    }
}

struct ImageEditorStylusTilt: Equatable {
    let x: CGFloat
    let y: CGFloat

    var magnitude: CGFloat {
        min(1, hypot(x, y))
    }

    var azimuthDegrees: Int? {
        guard magnitude > 0.0001 else { return nil }
        let rawDegrees = atan2(y, x) * 180 / .pi
        return Int((rawDegrees < 0 ? rawDegrees + 360 : rawDegrees).rounded()) % 360
    }
}

struct ImageEditorStylusEventSample: Equatable {
    let pressure: CGFloat?
    let tilt: ImageEditorStylusTilt?
}

enum ImageEditorStylusInput {
    static func sample(from event: NSEvent?) -> ImageEditorStylusEventSample {
        guard let event else {
            return ImageEditorStylusEventSample(pressure: nil, tilt: nil)
        }
        let supportsTilt = event.type == .tabletPoint || event.subtype == .tabletPoint
        let tilt = supportsTilt ? event.tilt : .zero
        return ImageEditorStylusEventSample(
            pressure: ImageEditorBrushPressureInput.pressure(from: event),
            tilt: normalizedTilt(
                rawX: tilt.x,
                rawY: tilt.y,
                supportsTilt: supportsTilt
            )
        )
    }

    static func normalizedTilt(
        rawX: CGFloat,
        rawY: CGFloat,
        supportsTilt: Bool
    ) -> ImageEditorStylusTilt? {
        guard supportsTilt, rawX.isFinite, rawY.isFinite else { return nil }
        return ImageEditorStylusTilt(
            x: max(-1, min(1, rawX)),
            y: max(-1, min(1, rawY))
        )
    }
}

struct ImageEditorBrushPressureDisplay: Equatable {
    let fraction: CGFloat
    let percent: Int?

    init(pressure: CGFloat?) {
        guard let pressure, pressure.isFinite else {
            fraction = 0
            percent = nil
            return
        }
        let normalized = max(0, min(1, pressure))
        fraction = normalized
        percent = Int((normalized * 100).rounded())
    }
}

struct ImageEditorStylusTiltDisplay: Equatable {
    let magnitudeFraction: CGFloat
    let magnitudePercent: Int?
    let azimuthDegrees: Int?

    init(tilt: ImageEditorStylusTilt?) {
        guard let tilt else {
            magnitudeFraction = 0
            magnitudePercent = nil
            azimuthDegrees = nil
            return
        }
        magnitudeFraction = tilt.magnitude
        magnitudePercent = Int((tilt.magnitude * 100).rounded())
        azimuthDegrees = tilt.azimuthDegrees
    }
}

enum ImageEditorStylusEraserProximity {
    static func nextState(
        current: Bool,
        isEraserDevice: Bool,
        enteringProximity: Bool
    ) -> Bool {
        if isEraserDevice {
            return enteringProximity
        }
        // A pen tip entering replaces any stale eraser-tip state. A leaving
        // event for an unrelated device must not cancel an eraser that is
        // still in proximity.
        return enteringProximity ? false : current
    }
}

enum ImageEditorStylusToolOverride {
    static func effectiveTool(
        baseTool: ImageEditorTool,
        sidebarTab: XomoLeftSidebarTab,
        isEraserInProximity: Bool
    ) -> ImageEditorTool {
        guard sidebarTab == .tools, isEraserInProximity else {
            return baseTool
        }
        return .eraser
    }
}
