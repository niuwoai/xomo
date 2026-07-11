import AppKit
import Foundation

enum XomoCanvasPreset: String, CaseIterable, Identifiable, Codable {
    case phonePortrait
    case phoneLandscape
    case tabletPortrait
    case tabletLandscape
    case webDesktop
    case webLaptop
    case webWide
    case desktopStandard
    case desktopWide
    case socialSquare
    case socialPortrait
    case socialBanner

    var id: String { rawValue }

    var title: String {
        L10n.text("xomo.canvasPreset.\(rawValue).title")
    }

    var category: XomoCanvasPresetCategory {
        switch self {
        case .phonePortrait, .phoneLandscape:
            .phone
        case .tabletPortrait, .tabletLandscape:
            .tablet
        case .webDesktop, .webLaptop, .webWide:
            .web
        case .desktopStandard, .desktopWide:
            .desktop
        case .socialSquare, .socialPortrait, .socialBanner:
            .social
        }
    }

    var logicalSize: CGSize {
        switch self {
        case .phonePortrait:
            CGSize(width: 390, height: 844)
        case .phoneLandscape:
            CGSize(width: 844, height: 390)
        case .tabletPortrait:
            CGSize(width: 834, height: 1194)
        case .tabletLandscape:
            CGSize(width: 1194, height: 834)
        case .webDesktop:
            CGSize(width: 1440, height: 1024)
        case .webLaptop:
            CGSize(width: 1280, height: 800)
        case .webWide:
            CGSize(width: 1920, height: 1080)
        case .desktopStandard:
            CGSize(width: 1280, height: 800)
        case .desktopWide:
            CGSize(width: 1440, height: 900)
        case .socialSquare:
            CGSize(width: 1080, height: 1080)
        case .socialPortrait:
            CGSize(width: 1080, height: 1350)
        case .socialBanner:
            CGSize(width: 1500, height: 500)
        }
    }

    var defaultExportScale: Int {
        switch self {
        case .phonePortrait, .phoneLandscape, .tabletPortrait, .tabletLandscape:
            3
        case .webDesktop, .webLaptop, .webWide, .desktopStandard, .desktopWide:
            1
        case .socialSquare, .socialPortrait, .socialBanner:
            1
        }
    }

    var suggestedMargin: CGFloat {
        switch category {
        case .phone:
            20
        case .tablet:
            32
        case .web, .desktop:
            48
        case .social:
            40
        }
    }
}

enum XomoCanvasPresetCategory: String, CaseIterable, Identifiable {
    case phone
    case tablet
    case web
    case desktop
    case social

    var id: String { rawValue }

    var title: String {
        L10n.text("xomo.canvasPresetCategory.\(rawValue)")
    }
}

enum XomoCanvasBackground: String, CaseIterable, Identifiable, Codable {
    case white
    case transparent

    var id: String { rawValue }

    var title: String {
        L10n.text("xomo.canvasBackground.\(rawValue)")
    }

    var color: NSColor {
        switch self {
        case .white:
            .white
        case .transparent:
            .clear
        }
    }
}

struct XomoCanvasDraft: Equatable {
    static let minimumDimension: CGFloat = 16
    static let maximumDimension: CGFloat = 8_192
    static let defaultGridSpacing: CGFloat = 8

    var selectedPreset: XomoCanvasPreset
    var width: Double
    var height: Double
    var exportScale: Int
    var background: XomoCanvasBackground

    init(preset: XomoCanvasPreset = .desktopWide, background: XomoCanvasBackground = .white) {
        selectedPreset = preset
        width = Double(preset.logicalSize.width)
        height = Double(preset.logicalSize.height)
        exportScale = preset.defaultExportScale
        self.background = background
    }

    var canvasSize: CGSize {
        CGSize(
            width: min(max(CGFloat(width.rounded()), Self.minimumDimension), Self.maximumDimension),
            height: min(max(CGFloat(height.rounded()), Self.minimumDimension), Self.maximumDimension)
        )
    }

    var clampedExportScale: Int {
        min(max(exportScale, 1), 3)
    }

    mutating func apply(_ preset: XomoCanvasPreset) {
        selectedPreset = preset
        width = Double(preset.logicalSize.width)
        height = Double(preset.logicalSize.height)
        exportScale = preset.defaultExportScale
    }
}

struct XomoDesignCanvasMetadata: Codable, Equatable {
    var preset: XomoCanvasPreset?
    var exportScale: Int
    var suggestedMargin: CGFloat
    var background: XomoCanvasBackground

    init(draft: XomoCanvasDraft) {
        preset = draft.canvasSize == draft.selectedPreset.logicalSize ? draft.selectedPreset : nil
        exportScale = draft.clampedExportScale
        suggestedMargin = draft.selectedPreset.suggestedMargin
        background = draft.background
    }
}
