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
            || event.stage > 0
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
