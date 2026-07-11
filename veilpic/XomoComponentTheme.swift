//
//  XomoComponentTheme.swift
//  veilpic
//

import AppKit
import Foundation

enum XomoComponentTheme: String, CaseIterable, Codable, Identifiable {
    case native
    case softMobile
    case denseAdmin

    var id: String { rawValue }

    var title: String {
        L10n.text("xomo.theme.\(rawValue)")
    }

    var tokens: XomoComponentThemeTokens {
        switch self {
        case .native:
            XomoComponentThemeTokens(
                accent: NSColor(deviceRed: 0.20, green: 0.48, blue: 0.95, alpha: 1),
                accentBorder: NSColor(deviceRed: 0.16, green: 0.39, blue: 0.78, alpha: 1),
                surface: NSColor(deviceWhite: 0.98, alpha: 1),
                subtleSurface: NSColor(deviceWhite: 0.94, alpha: 1),
                border: NSColor(deviceWhite: 0.80, alpha: 1),
                primaryText: NSColor(deviceWhite: 0.12, alpha: 1),
                secondaryText: NSColor(deviceWhite: 0.42, alpha: 1),
                onAccent: .white,
                cornerRadius: 8,
                spacing: 8
            )
        case .softMobile:
            XomoComponentThemeTokens(
                accent: NSColor(deviceRed: 0.53, green: 0.36, blue: 0.95, alpha: 1),
                accentBorder: NSColor(deviceRed: 0.42, green: 0.26, blue: 0.80, alpha: 1),
                surface: NSColor(deviceRed: 0.99, green: 0.98, blue: 1.0, alpha: 1),
                subtleSurface: NSColor(deviceRed: 0.94, green: 0.92, blue: 1.0, alpha: 1),
                border: NSColor(deviceRed: 0.83, green: 0.78, blue: 0.96, alpha: 1),
                primaryText: NSColor(deviceRed: 0.17, green: 0.12, blue: 0.31, alpha: 1),
                secondaryText: NSColor(deviceRed: 0.42, green: 0.35, blue: 0.57, alpha: 1),
                onAccent: .white,
                cornerRadius: 16,
                spacing: 12
            )
        case .denseAdmin:
            XomoComponentThemeTokens(
                accent: NSColor(deviceRed: 0.03, green: 0.58, blue: 0.47, alpha: 1),
                accentBorder: NSColor(deviceRed: 0.02, green: 0.44, blue: 0.36, alpha: 1),
                surface: NSColor(deviceRed: 0.96, green: 0.98, blue: 0.97, alpha: 1),
                subtleSurface: NSColor(deviceRed: 0.88, green: 0.93, blue: 0.91, alpha: 1),
                border: NSColor(deviceRed: 0.67, green: 0.75, blue: 0.72, alpha: 1),
                primaryText: NSColor(deviceRed: 0.08, green: 0.16, blue: 0.14, alpha: 1),
                secondaryText: NSColor(deviceRed: 0.29, green: 0.40, blue: 0.36, alpha: 1),
                onAccent: .white,
                cornerRadius: 4,
                spacing: 6
            )
        }
    }
}

struct XomoComponentThemeTokens {
    let accent: NSColor
    let accentBorder: NSColor
    let surface: NSColor
    let subtleSurface: NSColor
    let border: NSColor
    let primaryText: NSColor
    let secondaryText: NSColor
    let onAccent: NSColor
    let cornerRadius: CGFloat
    let spacing: CGFloat
}
