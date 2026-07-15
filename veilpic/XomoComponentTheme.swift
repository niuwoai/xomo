//
//  XomoComponentTheme.swift
//  veilpic
//

import AppKit
import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let xomoDesignTokens = UTType(
        exportedAs: "im.some.xomo.design-tokens",
        conformingTo: .json
    )
}

enum XomoComponentTheme: String, CaseIterable, Codable, Identifiable {
    case native
    case softMobile
    case socialContent
    case glassmorphism
    case denseAdmin
    case chakraUI
    case radixThemes

    var id: String { rawValue }

    var title: String {
        L10n.text("xomo.theme.\(rawValue)")
    }

    var librarySource: XomoComponentLibrarySource {
        switch self {
        case .native, .softMobile, .socialContent, .glassmorphism, .denseAdmin:
            .xomoOriginal
        case .chakraUI:
            .chakraUI
        case .radixThemes:
            .radixThemes
        }
    }

    var libraryTitle: String {
        L10n.format("xomo.theme.libraryTitle", librarySource.title, title)
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
        case .socialContent:
            XomoComponentThemeTokens(
                accent: NSColor(deviceRed: 0.93, green: 0.27, blue: 0.40, alpha: 1),
                accentBorder: NSColor(deviceRed: 0.72, green: 0.12, blue: 0.25, alpha: 1),
                surface: NSColor(deviceRed: 1.0, green: 0.98, blue: 0.97, alpha: 1),
                subtleSurface: NSColor(deviceRed: 1.0, green: 0.91, blue: 0.92, alpha: 1),
                border: NSColor(deviceRed: 0.96, green: 0.73, blue: 0.76, alpha: 1),
                primaryText: NSColor(deviceRed: 0.20, green: 0.08, blue: 0.12, alpha: 1),
                secondaryText: NSColor(deviceRed: 0.48, green: 0.24, blue: 0.29, alpha: 1),
                onAccent: .white,
                cornerRadius: 20,
                spacing: 12
            )
        case .glassmorphism:
            XomoComponentThemeTokens(
                accent: NSColor(deviceRed: 0.39, green: 0.78, blue: 1.0, alpha: 1),
                accentBorder: NSColor(deviceRed: 0.65, green: 0.87, blue: 1.0, alpha: 1),
                surface: NSColor(deviceRed: 0.10, green: 0.15, blue: 0.29, alpha: 0.72),
                subtleSurface: NSColor(deviceRed: 0.22, green: 0.30, blue: 0.49, alpha: 0.56),
                border: NSColor(deviceRed: 0.73, green: 0.87, blue: 1.0, alpha: 0.50),
                primaryText: NSColor(deviceRed: 0.96, green: 0.98, blue: 1.0, alpha: 1),
                secondaryText: NSColor(deviceRed: 0.76, green: 0.85, blue: 0.96, alpha: 1),
                onAccent: NSColor(deviceRed: 0.04, green: 0.11, blue: 0.20, alpha: 1),
                cornerRadius: 18,
                spacing: 14
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
        case .chakraUI:
            XomoComponentThemeTokens(
                accent: NSColor(deviceRed: 0.13, green: 0.58, blue: 0.60, alpha: 1),
                accentBorder: NSColor(deviceRed: 0.10, green: 0.45, blue: 0.47, alpha: 1),
                surface: .white,
                subtleSurface: NSColor(deviceRed: 0.93, green: 0.98, blue: 0.98, alpha: 1),
                border: NSColor(deviceRed: 0.82, green: 0.87, blue: 0.88, alpha: 1),
                primaryText: NSColor(deviceRed: 0.10, green: 0.12, blue: 0.15, alpha: 1),
                secondaryText: NSColor(deviceRed: 0.35, green: 0.40, blue: 0.43, alpha: 1),
                onAccent: .white,
                cornerRadius: 6,
                spacing: 8
            )
        case .radixThemes:
            XomoComponentThemeTokens(
                accent: NSColor(deviceRed: 0.24, green: 0.39, blue: 0.87, alpha: 1),
                accentBorder: NSColor(deviceRed: 0.18, green: 0.29, blue: 0.66, alpha: 1),
                surface: NSColor(deviceRed: 0.99, green: 0.99, blue: 1.0, alpha: 1),
                subtleSurface: NSColor(deviceRed: 0.94, green: 0.95, blue: 0.99, alpha: 1),
                border: NSColor(deviceRed: 0.80, green: 0.83, blue: 0.93, alpha: 1),
                primaryText: NSColor(deviceRed: 0.10, green: 0.12, blue: 0.19, alpha: 1),
                secondaryText: NSColor(deviceRed: 0.35, green: 0.39, blue: 0.49, alpha: 1),
                onAccent: .white,
                cornerRadius: 8,
                spacing: 8
            )
        }
    }
}

enum XomoComponentLibrarySource: String, CaseIterable, Identifiable {
    case xomoOriginal
    case chakraUI
    case radixThemes

    var id: String { rawValue }

    var title: String {
        L10n.text("xomo.librarySource.\(rawValue)")
    }

    var attribution: String {
        L10n.text("xomo.librarySource.\(rawValue).attribution")
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

enum XomoComponentThemeTokenError: Error, Equatable {
    case unsupportedSchema(Int)
    case missingColor(String)
    case invalidColor(String)
    case missingMetric(String)
    case invalidMetric(String)
}

struct XomoComponentThemeTokenSnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let theme: String
    let librarySource: String
    let colors: [String: String]
    let metrics: [String: Double]

    init(
        schemaVersion: Int = 1,
        theme: String,
        librarySource: String,
        colors: [String: String],
        metrics: [String: Double]
    ) {
        self.schemaVersion = schemaVersion
        self.theme = theme
        self.librarySource = librarySource
        self.colors = colors
        self.metrics = metrics
    }

    init(theme: XomoComponentTheme, tokens: XomoComponentThemeTokens) {
        schemaVersion = 1
        self.theme = theme.rawValue
        librarySource = theme.librarySource.rawValue
        colors = [
            "accent": tokens.accent.xomoRGBAHex,
            "accentBorder": tokens.accentBorder.xomoRGBAHex,
            "surface": tokens.surface.xomoRGBAHex,
            "subtleSurface": tokens.subtleSurface.xomoRGBAHex,
            "border": tokens.border.xomoRGBAHex,
            "primaryText": tokens.primaryText.xomoRGBAHex,
            "secondaryText": tokens.secondaryText.xomoRGBAHex,
            "onAccent": tokens.onAccent.xomoRGBAHex
        ]
        metrics = [
            "cornerRadius": tokens.cornerRadius,
            "spacing": tokens.spacing
        ]
    }

    func encodedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard let json = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                self,
                EncodingError.Context(codingPath: [], debugDescription: "Token JSON is not UTF-8")
            )
        }
        return json
    }

    func makeTokens() throws -> XomoComponentThemeTokens {
        guard schemaVersion == 1 else {
            throw XomoComponentThemeTokenError.unsupportedSchema(schemaVersion)
        }

        func color(_ key: String) throws -> NSColor {
            guard let value = colors[key] else {
                throw XomoComponentThemeTokenError.missingColor(key)
            }
            guard let color = NSColor(xomoRGBAHex: value) else {
                throw XomoComponentThemeTokenError.invalidColor(key)
            }
            return color
        }

        func metric(_ key: String) throws -> CGFloat {
            guard let value = metrics[key] else {
                throw XomoComponentThemeTokenError.missingMetric(key)
            }
            guard value.isFinite, value >= 0, value <= 1_000 else {
                throw XomoComponentThemeTokenError.invalidMetric(key)
            }
            return CGFloat(value)
        }

        return XomoComponentThemeTokens(
            accent: try color("accent"),
            accentBorder: try color("accentBorder"),
            surface: try color("surface"),
            subtleSurface: try color("subtleSurface"),
            border: try color("border"),
            primaryText: try color("primaryText"),
            secondaryText: try color("secondaryText"),
            onAccent: try color("onAccent"),
            cornerRadius: try metric("cornerRadius"),
            spacing: try metric("spacing")
        )
    }
}

extension XomoComponentTheme {
    var tokenSnapshot: XomoComponentThemeTokenSnapshot {
        XomoComponentThemeTokenSnapshot(theme: self, tokens: tokens)
    }
}

private extension NSColor {
    convenience init?(xomoRGBAHex value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.hasPrefix("#"), normalized.count == 9 else { return nil }
        let hex = String(normalized.dropFirst())
        guard let rgba = UInt64(hex, radix: 16) else { return nil }
        self.init(
            deviceRed: CGFloat((rgba >> 24) & 0xFF) / 255,
            green: CGFloat((rgba >> 16) & 0xFF) / 255,
            blue: CGFloat((rgba >> 8) & 0xFF) / 255,
            alpha: CGFloat(rgba & 0xFF) / 255
        )
    }

    var xomoRGBAHex: String {
        let color = usingColorSpace(.sRGB) ?? self
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        let alpha = Int((color.alphaComponent * 255).rounded())
        return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
    }
}

struct XomoComponentInstance: Codable, Equatable {
    var kind: XomoComponentKind
    var theme: XomoComponentTheme
    var masterID: UUID?
    var tokenSnapshot: XomoComponentThemeTokenSnapshot?

    init(
        kind: XomoComponentKind,
        theme: XomoComponentTheme,
        masterID: UUID? = nil,
        tokenSnapshot: XomoComponentThemeTokenSnapshot? = nil
    ) {
        self.kind = kind
        self.theme = theme
        self.masterID = masterID
        self.tokenSnapshot = tokenSnapshot
    }
}

enum XomoThemeSample: CaseIterable, Identifiable {
    case nativeWorkspace
    case softMobileProfile
    case socialContentFeed
    case glassmorphismDashboard
    case denseAdminSettings
    case chakraForm
    case radixSettings

    var id: String { rawValue }

    var rawValue: String {
        switch self {
        case .nativeWorkspace: "nativeWorkspace"
        case .softMobileProfile: "softMobileProfile"
        case .socialContentFeed: "socialContentFeed"
        case .glassmorphismDashboard: "glassmorphismDashboard"
        case .denseAdminSettings: "denseAdminSettings"
        case .chakraForm: "chakraForm"
        case .radixSettings: "radixSettings"
        }
    }

    var theme: XomoComponentTheme {
        switch self {
        case .nativeWorkspace: .native
        case .softMobileProfile: .softMobile
        case .socialContentFeed: .socialContent
        case .glassmorphismDashboard: .glassmorphism
        case .denseAdminSettings: .denseAdmin
        case .chakraForm: .chakraUI
        case .radixSettings: .radixThemes
        }
    }

    var title: String {
        L10n.text("xomo.themeSample.\(rawValue)")
    }

    static func sample(for theme: XomoComponentTheme) -> Self {
        switch theme {
        case .native: .nativeWorkspace
        case .softMobile: .softMobileProfile
        case .socialContent: .socialContentFeed
        case .glassmorphism: .glassmorphismDashboard
        case .denseAdmin: .denseAdminSettings
        case .chakraUI: .chakraForm
        case .radixThemes: .radixSettings
        }
    }
}
