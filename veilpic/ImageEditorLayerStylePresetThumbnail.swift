//
//  ImageEditorLayerStylePresetThumbnail.swift
//  veilpic
//
//  Created by Codex on 2026/7/14.
//

import AppKit
import SwiftUI

@MainActor
enum ImageEditorLayerStylePresetPreviewRenderer {
    static let previewSize = CGSize(width: 80, height: 52)

    private static let contentSize = CGSize(width: 42, height: 24)
    private static let cache = NSCache<NSString, NSImage>()

    static func image(for preset: ImageEditorLayerStylePreset) -> NSImage {
        let cacheKey = preset.id as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let baseImage = NSImage.rendered(size: contentSize) { rect in
            NSColor(deviceRed: 0.54, green: 0.60, blue: 0.68, alpha: 1).setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5).fill()
        } ?? NSImage.transparent(size: contentSize)
        var layer = ImageEditorLayer.blank(name: preset.title, size: contentSize)
        layer.image = baseImage
        layer.style = preset.layerStyle
        let styledImage = layer.renderedCompositingImage(globalLightAngle: -45)
        let rendered = NSImage.rendered(size: previewSize) { rect in
            checkerboard(in: rect)
            let targetRect = aspectFitRect(size: styledImage.size, in: rect.insetBy(dx: 7, dy: 6))
            styledImage.draw(
                in: targetRect,
                from: CGRect(origin: .zero, size: styledImage.size),
                operation: .sourceOver,
                fraction: preset.layerStyle.effectsEnabled ? 1 : 0.46
            )
        } ?? NSImage.transparent(size: previewSize)
        cache.setObject(rendered, forKey: cacheKey)
        return rendered
    }

    private static func checkerboard(in rect: CGRect) {
        let cellSize: CGFloat = 8
        let columns = Int(ceil(rect.width / cellSize))
        let rows = Int(ceil(rect.height / cellSize))
        for row in 0..<rows {
            for column in 0..<columns {
                let isLight = (row + column).isMultiple(of: 2)
                NSColor(white: isLight ? 0.31 : 0.24, alpha: 1).setFill()
                CGRect(
                    x: CGFloat(column) * cellSize,
                    y: CGFloat(row) * cellSize,
                    width: cellSize,
                    height: cellSize
                ).fill()
            }
        }
    }

    private static func aspectFitRect(size: CGSize, in bounds: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return bounds }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fittedSize = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(
            x: bounds.midX - fittedSize.width / 2,
            y: bounds.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}

struct ImageEditorLayerStylePresetThumbnail: View {
    let preset: ImageEditorLayerStylePreset
    var width: CGFloat = 40
    var height: CGFloat = 26

    var body: some View {
        Image(nsImage: ImageEditorLayerStylePresetPreviewRenderer.image(for: preset))
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}
