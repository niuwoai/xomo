//
//  PostProcessing.swift
//  veilpic
//
//  Created by Codex on 2026/6/30.
//

import AppKit
import Foundation

enum PostProcessTemplate: String, CaseIterable, Identifiable, Codable, Sendable {
    case original
    case rounded
    case gradient
    case iPhone
    case iPad
    case macBook

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            L10n.text("post.template.original")
        case .rounded:
            L10n.text("post.template.rounded")
        case .gradient:
            L10n.text("post.template.gradient")
        case .iPhone:
            L10n.text("post.template.iphone")
        case .iPad:
            L10n.text("post.template.ipad")
        case .macBook:
            L10n.text("post.template.macbook")
        }
    }

    var symbolName: String {
        switch self {
        case .original:
            "photo"
        case .rounded:
            "rectangle.roundedtop"
        case .gradient:
            "paintpalette"
        case .iPhone:
            "iphone"
        case .iPad:
            "ipad"
        case .macBook:
            "macbook"
        }
    }
}

struct ImageWorkspaceItem: Identifiable {
    let id = UUID()
    let originalImage: NSImage
    let sourceName: String
    let createdAt: Date

    var pixelSizeText: String {
        let size = originalImage.size
        return "\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
    }
}

extension NSImage {
    func qingtuPNGData() -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation)
        else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}

struct PostProcessRecipe: Equatable {
    var template: PostProcessTemplate = .original
    var paddingScale: CGFloat = 0.16
    var cornerRadius: CGFloat = 28
    var shadowRadius: CGFloat = 22
    var background: PostProcessBackground = .seaSalt

    static func defaults(for template: PostProcessTemplate) -> PostProcessRecipe {
        switch template {
        case .original:
            return PostProcessRecipe(template: template, paddingScale: 0, cornerRadius: 0, shadowRadius: 0, background: .transparent)
        case .rounded:
            return PostProcessRecipe(template: template, paddingScale: 0.12, cornerRadius: 30, shadowRadius: 18, background: .porcelain)
        case .gradient:
            return PostProcessRecipe(template: template, paddingScale: 0.18, cornerRadius: 30, shadowRadius: 24, background: .seaSalt)
        case .iPhone:
            return PostProcessRecipe(template: template, paddingScale: 0.22, cornerRadius: 36, shadowRadius: 26, background: .seaSalt)
        case .iPad:
            return PostProcessRecipe(template: template, paddingScale: 0.18, cornerRadius: 28, shadowRadius: 24, background: .porcelain)
        case .macBook:
            return PostProcessRecipe(template: template, paddingScale: 0.18, cornerRadius: 22, shadowRadius: 28, background: .seaSalt)
        }
    }
}

enum PostProcessBackground: String, CaseIterable, Identifiable, Equatable, Codable, Sendable {
    case transparent
    case porcelain
    case seaSalt
    case warmGlow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transparent:
            L10n.text("post.background.transparent")
        case .porcelain:
            L10n.text("post.background.porcelain")
        case .seaSalt:
            L10n.text("post.background.seaSalt")
        case .warmGlow:
            L10n.text("post.background.warmGlow")
        }
    }
}

final class PostProcessRenderer {
    func render(image: NSImage, recipe: PostProcessRecipe) -> NSImage {
        switch recipe.template {
        case .original:
            return image
        case .rounded:
            return renderRounded(image: image, recipe: recipe)
        case .gradient:
            return renderRounded(image: image, recipe: recipe)
        case .iPhone:
            return renderDevice(image: image, recipe: recipe, device: .iPhone)
        case .iPad:
            return renderDevice(image: image, recipe: recipe, device: .iPad)
        case .macBook:
            return renderDevice(image: image, recipe: recipe, device: .macBook)
        }
    }

    private func renderRounded(image: NSImage, recipe: PostProcessRecipe) -> NSImage {
        let sourceSize = normalizedSize(for: image)
        let padding = max(min(sourceSize.width, sourceSize.height) * recipe.paddingScale, 28)
        let canvasSize = CGSize(width: sourceSize.width + padding * 2, height: sourceSize.height + padding * 2)
        let imageRect = CGRect(origin: CGPoint(x: padding, y: padding), size: sourceSize)

        return draw(size: canvasSize) { context in
            drawBackground(recipe.background, in: CGRect(origin: .zero, size: canvasSize), context: context)
            drawRoundedImage(image, in: imageRect, radius: recipe.cornerRadius, shadowRadius: recipe.shadowRadius, context: context)
        }
    }

    private func renderDevice(image: NSImage, recipe: PostProcessRecipe, device: DeviceFrameKind) -> NSImage {
        let sourceSize = normalizedSize(for: image)
        let deviceSize = device.outerSize(forContentSize: sourceSize)
        let padding = max(min(deviceSize.width, deviceSize.height) * recipe.paddingScale, 34)
        let canvasSize = CGSize(width: deviceSize.width + padding * 2, height: deviceSize.height + padding * 2)
        let deviceRect = CGRect(origin: CGPoint(x: padding, y: padding), size: deviceSize)

        return draw(size: canvasSize) { context in
            drawBackground(recipe.background, in: CGRect(origin: .zero, size: canvasSize), context: context)
            drawDeviceFrame(device, image: image, in: deviceRect, context: context)
        }
    }

    private func draw(size: CGSize, actions: (CGContext) -> Void) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            actions(context)
        }
        image.unlockFocus()
        return image
    }

    private func normalizedSize(for image: NSImage) -> CGSize {
        let size = image.size
        let maxSide: CGFloat = 1800
        guard max(size.width, size.height) > maxSide else { return size }
        let ratio = maxSide / max(size.width, size.height)
        return CGSize(width: size.width * ratio, height: size.height * ratio)
    }

    private func drawBackground(_ background: PostProcessBackground, in rect: CGRect, context: CGContext) {
        switch background {
        case .transparent:
            NSColor.clear.setFill()
            rect.fill()
        case .porcelain:
            NSColor(calibratedRed: 0.98, green: 0.99, blue: 0.96, alpha: 1).setFill()
            rect.fill()
        case .seaSalt:
            drawLinearGradient(
                colors: [
                    NSColor(calibratedRed: 0.91, green: 0.97, blue: 0.98, alpha: 1),
                    NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.90, alpha: 1),
                    NSColor(calibratedRed: 0.86, green: 0.94, blue: 0.95, alpha: 1)
                ],
                in: rect,
                context: context
            )
        case .warmGlow:
            drawLinearGradient(
                colors: [
                    NSColor(calibratedRed: 0.99, green: 0.96, blue: 0.90, alpha: 1),
                    NSColor(calibratedRed: 0.91, green: 0.97, blue: 0.98, alpha: 1)
                ],
                in: rect,
                context: context
            )
        }
    }

    private func drawLinearGradient(colors: [NSColor], in rect: CGRect, context: CGContext) {
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map(\.cgColor) as CFArray,
            locations: nil
        ) else {
            colors.first?.setFill()
            rect.fill()
            return
        }

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.maxY),
            end: CGPoint(x: rect.maxX, y: rect.minY),
            options: []
        )
    }

    private func drawRoundedImage(_ image: NSImage, in rect: CGRect, radius: CGFloat, shadowRadius: CGFloat, context: CGContext) {
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -10),
            blur: shadowRadius,
            color: NSColor(calibratedRed: 0.18, green: 0.34, blue: 0.42, alpha: 0.18).cgColor
        )
        context.addPath(path)
        context.setFillColor(NSColor.white.cgColor)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(path)
        context.clip()
        image.draw(in: rect, from: CGRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
        context.restoreGState()
    }

    private func drawDeviceFrame(_ device: DeviceFrameKind, image: NSImage, in rect: CGRect, context: CGContext) {
        switch device {
        case .iPhone:
            drawRoundedDevice(image, in: rect, cornerRadiusRatio: 0.105, bezelRatio: 0.055, context: context)
        case .iPad:
            drawRoundedDevice(image, in: rect, cornerRadiusRatio: 0.055, bezelRatio: 0.042, context: context)
        case .macBook:
            drawMacBook(image, in: rect, context: context)
        }
    }

    private func drawRoundedDevice(
        _ image: NSImage,
        in rect: CGRect,
        cornerRadiusRatio: CGFloat,
        bezelRatio: CGFloat,
        context: CGContext
    ) {
        let cornerRadius = min(rect.width, rect.height) * cornerRadiusRatio
        let bezel = min(rect.width, rect.height) * bezelRatio
        let screenRect = rect.insetBy(dx: bezel, dy: bezel)

        drawShadowedRoundedRect(rect, radius: cornerRadius, fill: NSColor(calibratedWhite: 0.08, alpha: 1), context: context)
        drawRoundedImage(image, in: screenRect, radius: max(cornerRadius - bezel, 16), shadowRadius: 0, context: context)

        let highlightPath = CGPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.saveGState()
        context.addPath(highlightPath)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
        context.setLineWidth(2)
        context.strokePath()
        context.restoreGState()
    }

    private func drawMacBook(_ image: NSImage, in rect: CGRect, context: CGContext) {
        let baseHeight = rect.height * 0.11
        let screenRect = CGRect(x: rect.minX, y: rect.minY + baseHeight, width: rect.width, height: rect.height - baseHeight)
        let bezel = min(screenRect.width, screenRect.height) * 0.045
        let displayRect = screenRect.insetBy(dx: bezel, dy: bezel)

        drawShadowedRoundedRect(screenRect, radius: 24, fill: NSColor(calibratedWhite: 0.10, alpha: 1), context: context)
        drawRoundedImage(image, in: displayRect, radius: 12, shadowRadius: 0, context: context)

        let baseRect = CGRect(x: rect.minX - rect.width * 0.06, y: rect.minY, width: rect.width * 1.12, height: baseHeight)
        let basePath = CGPath(roundedRect: baseRect, cornerWidth: 18, cornerHeight: 18, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: NSColor.black.withAlphaComponent(0.18).cgColor)
        context.addPath(basePath)
        context.setFillColor(NSColor(calibratedRed: 0.74, green: 0.78, blue: 0.79, alpha: 1).cgColor)
        context.fillPath()
        context.restoreGState()

        let notchRect = CGRect(x: baseRect.midX - 42, y: baseRect.maxY - 10, width: 84, height: 8)
        let notchPath = CGPath(roundedRect: notchRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
        context.addPath(notchPath)
        context.setFillColor(NSColor(calibratedWhite: 0.56, alpha: 0.55).cgColor)
        context.fillPath()
    }

    private func drawShadowedRoundedRect(_ rect: CGRect, radius: CGFloat, fill: NSColor, context: CGContext) {
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -12), blur: 26, color: NSColor.black.withAlphaComponent(0.22).cgColor)
        context.addPath(path)
        context.setFillColor(fill.cgColor)
        context.fillPath()
        context.restoreGState()
    }
}

private enum DeviceFrameKind {
    case iPhone
    case iPad
    case macBook

    func outerSize(forContentSize contentSize: CGSize) -> CGSize {
        switch self {
        case .iPhone:
            let height = max(contentSize.height * 1.22, 620)
            return CGSize(width: height * 0.50, height: height)
        case .iPad:
            let width = max(contentSize.width * 1.12, 760)
            return CGSize(width: width, height: width * 0.72)
        case .macBook:
            let width = max(contentSize.width * 1.16, 900)
            return CGSize(width: width, height: width * 0.68)
        }
    }
}
