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
