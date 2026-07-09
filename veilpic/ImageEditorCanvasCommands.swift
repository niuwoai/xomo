//
//  ImageEditorCanvasCommands.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Foundation

enum ImageEditorCanvasAnchor: String, CaseIterable, Identifiable {
    case topLeft
    case top
    case topRight
    case left
    case center
    case right
    case bottomLeft
    case bottom
    case bottomRight

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.canvasAnchor.\(rawValue)")
    }

    var horizontalFactor: CGFloat {
        switch self {
        case .topLeft, .left, .bottomLeft:
            0
        case .top, .center, .bottom:
            0.5
        case .topRight, .right, .bottomRight:
            1
        }
    }

    var verticalFactor: CGFloat {
        switch self {
        case .bottomLeft, .bottom, .bottomRight:
            0
        case .left, .center, .right:
            0.5
        case .topLeft, .top, .topRight:
            1
        }
    }
}

@MainActor
extension ImageEditorViewModel {
    func syncSizeControlsFromDocument() {
        targetImageWidth = Double(document.canvasSize.width.rounded())
        targetImageHeight = Double(document.canvasSize.height.rounded())
        targetCanvasWidth = Double(document.canvasSize.width.rounded())
        targetCanvasHeight = Double(document.canvasSize.height.rounded())
    }

    func resizeImageToControlSize() {
        resizeImage(to: CGSize(width: targetImageWidth, height: targetImageHeight))
    }

    func resizeCanvasToControlSize() {
        resizeCanvas(to: CGSize(width: targetCanvasWidth, height: targetCanvasHeight), anchor: selectedCanvasAnchor)
    }

    func resizeImage(to targetSize: CGSize) {
        guard let targetSize = normalizedEditorSize(targetSize),
              targetSize != document.canvasSize
        else {
            statusText = L10n.text("imageEditor.status.resizeInvalid")
            return
        }

        let originalSize = document.canvasSize
        let scaleX = targetSize.width / max(originalSize.width, 1)
        let scaleY = targetSize.height / max(originalSize.height, 1)
        let transformedLayers = document.layers.map { layer in
            layer.scaledForImageSize(scaleX: scaleX, scaleY: scaleY)
        }
        let transformedGuides = scaledGuides(scaleX: scaleX, scaleY: scaleY, targetCanvasSize: targetSize)

        pushUndo()
        document.canvasSize = targetSize
        document.layers = transformedLayers
        document.guides = transformedGuides
        document.selection = document.selection?.scaled(scaleX: scaleX, scaleY: scaleY, targetSize: targetSize)
        document.savedSelection = document.savedSelection?.scaled(scaleX: scaleX, scaleY: scaleY, targetSize: targetSize)
        document.alphaChannels = document.alphaChannels.map { channel in
            ImageEditorAlphaChannel(
                id: channel.id,
                name: channel.name,
                mask: channel.mask.resizedNearest(to: targetSize)
            )
        }
        canvasOffset = .zero
        syncSizeControlsFromDocument()
        appendHistory(L10n.text("imageEditor.history.imageResize"))
    }

    func resizeCanvas(to targetSize: CGSize, anchor: ImageEditorCanvasAnchor) {
        guard let targetSize = normalizedEditorSize(targetSize),
              targetSize != document.canvasSize
        else {
            statusText = L10n.text("imageEditor.status.resizeInvalid")
            return
        }

        let originalSize = document.canvasSize
        let offset = CGSize(
            width: (targetSize.width - originalSize.width) * anchor.horizontalFactor,
            height: (targetSize.height - originalSize.height) * anchor.verticalFactor
        )
        let transformedLayers = document.layers.map { layer in
            layer.offsetForCanvasSize(
                oldCanvasSize: originalSize,
                newCanvasSize: targetSize,
                offset: offset
            )
        }
        let transformedGuides = offsetGuides(by: offset, targetCanvasSize: targetSize)

        pushUndo()
        document.canvasSize = targetSize
        document.layers = transformedLayers
        document.guides = transformedGuides
        document.selection = document.selection?.offsetForCanvasResize(
            oldCanvasSize: originalSize,
            newCanvasSize: targetSize,
            offset: offset
        )
        document.savedSelection = document.savedSelection?.offsetForCanvasResize(
            oldCanvasSize: originalSize,
            newCanvasSize: targetSize,
            offset: offset
        )
        document.alphaChannels = document.alphaChannels.map { channel in
            ImageEditorAlphaChannel(
                id: channel.id,
                name: channel.name,
                mask: channel.mask.canvasResized(to: targetSize, oldCanvasSize: originalSize, offset: offset)
            )
        }
        canvasOffset = .zero
        syncSizeControlsFromDocument()
        appendHistory(L10n.text("imageEditor.history.canvasResize"))
    }

    func cropCenter() {
        let size = document.canvasSize
        let cropRect = CGRect(
            x: size.width * 0.08,
            y: size.height * 0.08,
            width: size.width * 0.84,
            height: size.height * 0.84
        )
        crop(to: cropRect)
    }

    func crop(to rect: CGRect) {
        let originalSize = document.canvasSize
        let bounded = rect.standardized
            .intersection(CGRect(origin: .zero, size: originalSize))
            .integral
        guard bounded.width >= 8,
              bounded.height >= 8,
              bounded.width < originalSize.width || bounded.height < originalSize.height
        else {
            statusText = L10n.text("imageEditor.status.resizeInvalid")
            return
        }

        let targetSize = bounded.size
        let offset = CGSize(width: -bounded.minX, height: -bounded.minY)
        let transformedLayers = document.layers.map { layer in
            layer.offsetForCanvasSize(
                oldCanvasSize: originalSize,
                newCanvasSize: targetSize,
                offset: offset
            )
        }
        let transformedGuides = offsetGuides(by: offset, targetCanvasSize: targetSize)

        pushUndo()
        document.canvasSize = targetSize
        document.layers = transformedLayers
        document.guides = transformedGuides
        document.selection = document.selection?.offsetForCanvasResize(
            oldCanvasSize: originalSize,
            newCanvasSize: targetSize,
            offset: offset
        )
        document.savedSelection = document.savedSelection?.offsetForCanvasResize(
            oldCanvasSize: originalSize,
            newCanvasSize: targetSize,
            offset: offset
        )
        document.alphaChannels = document.alphaChannels.map { channel in
            ImageEditorAlphaChannel(
                id: channel.id,
                name: channel.name,
                mask: channel.mask.canvasResized(to: targetSize, oldCanvasSize: originalSize, offset: offset)
            )
        }
        canvasOffset = .zero
        syncSizeControlsFromDocument()
        appendHistory(L10n.text("imageEditor.history.crop"))
    }

    private func normalizedEditorSize(_ size: CGSize) -> CGSize? {
        let width = CGFloat(size.width.rounded())
        let height = CGFloat(size.height.rounded())
        guard width >= 8, height >= 8, width <= 12_000, height <= 12_000 else { return nil }
        return CGSize(width: width, height: height)
    }
}

private extension ImageEditorLayer {
    func scaledForImageSize(scaleX: CGFloat, scaleY: CGFloat) -> ImageEditorLayer {
        var layer = self
        layer.frame = frame.scaled(scaleX: scaleX, scaleY: scaleY)
        let targetLayerSize = frame.size.scaled(scaleX: scaleX, scaleY: scaleY)
        layer.image = image.resized(to: targetLayerSize) ?? NSImage.transparent(size: targetLayerSize)
        layer.mask = mask?.resized(to: targetLayerSize)
        layer.vectorMask = vectorMask?.scaled(scaleX: scaleX, scaleY: scaleY)
        layer.style = style.scaled(by: (scaleX + scaleY) / 2)

        switch kind {
        case .text(var content):
            content = content.scaled(scaleX: scaleX, scaleY: scaleY)
            layer.kind = .text(content)
            layer.image = NSImage.transparent(size: targetLayerSize)
        case .shape(var content):
            content = content.scaled(scaleX: scaleX, scaleY: scaleY)
            layer.kind = .shape(content)
            layer.image = content.renderedImage(size: targetLayerSize)
        case .smartObject:
            layer.image = image
            layer.mask = mask
            layer.vectorMask = vectorMask
        case .group, .pixel, .adjustment, .filter:
            break
        }
        return layer
    }

    func offsetForCanvasSize(oldCanvasSize: CGSize, newCanvasSize: CGSize, offset: CGSize) -> ImageEditorLayer {
        var layer = self
        layer.frame = frame.offsetBy(dx: offset.width, dy: offset.height)
        if isCanvasSizedMask(mask, oldCanvasSize: oldCanvasSize) {
            layer.mask = mask?.canvasResized(to: newCanvasSize, oldCanvasSize: oldCanvasSize, offset: offset)
        }
        return layer
    }

    private func isCanvasSizedMask(_ mask: NSImage?, oldCanvasSize: CGSize) -> Bool {
        guard let mask else { return false }
        return abs(mask.size.width - oldCanvasSize.width) < 0.5
            && abs(mask.size.height - oldCanvasSize.height) < 0.5
    }
}

private extension CGRect {
    func scaled(scaleX: CGFloat, scaleY: CGFloat) -> CGRect {
        CGRect(
            x: minX * scaleX,
            y: minY * scaleY,
            width: max(1, width * scaleX),
            height: max(1, height * scaleY)
        )
    }
}

private extension CGSize {
    func scaled(scaleX: CGFloat, scaleY: CGFloat) -> CGSize {
        CGSize(width: max(1, width * scaleX), height: max(1, height * scaleY))
    }
}

private extension CGPoint {
    func scaled(scaleX: CGFloat, scaleY: CGFloat) -> CGPoint {
        CGPoint(x: x * scaleX, y: y * scaleY)
    }

    func offset(by offset: CGSize) -> CGPoint {
        CGPoint(x: x + offset.width, y: y + offset.height)
    }
}

private extension ImageEditorTextContent {
    func scaled(scaleX: CGFloat, scaleY: CGFloat) -> ImageEditorTextContent {
        let averageScale = (scaleX + scaleY) / 2
        var content = self
        content.fontSize = max(6, fontSize * averageScale)
        content.point = point.scaled(scaleX: scaleX, scaleY: scaleY)
        content.characterSpacing *= averageScale
        content.lineSpacing *= scaleY
        if content.boxWidth > 0 {
            content.boxWidth = max(1, boxWidth * scaleX)
        }
        return content
    }
}

private extension ImageEditorShapeContent {
    func scaled(scaleX: CGFloat, scaleY: CGFloat) -> ImageEditorShapeContent {
        let averageScale = (scaleX + scaleY) / 2
        var content = self
        content.strokeWidth = max(Self.minimumStrokeWidth, strokeWidth * averageScale)
        content.pathPoints = pathPoints.map { $0.scaled(scaleX: scaleX, scaleY: scaleY) }
        content.pathAnchors = pathAnchors.map { anchor in
            ImageEditorPathAnchor(
                point: anchor.point.scaled(scaleX: scaleX, scaleY: scaleY),
                inControl: anchor.inControl?.scaled(scaleX: scaleX, scaleY: scaleY),
                outControl: anchor.outControl?.scaled(scaleX: scaleX, scaleY: scaleY)
            )
        }
        content.pathSubpaths = pathSubpaths.map { subpath in
            subpath.map { anchor in
                ImageEditorPathAnchor(
                    point: anchor.point.scaled(scaleX: scaleX, scaleY: scaleY),
                    inControl: anchor.inControl?.scaled(scaleX: scaleX, scaleY: scaleY),
                    outControl: anchor.outControl?.scaled(scaleX: scaleX, scaleY: scaleY)
                )
            }
        }
        return content
    }
}

private extension ImageEditorLayerStyle {
    func scaled(by scale: CGFloat) -> ImageEditorLayerStyle {
        var style = self
        style.strokeWidth *= scale
        style.shadowBlur *= scale
        style.shadowOffset = CGSize(width: shadowOffset.width * scale, height: shadowOffset.height * scale)
        style.innerShadowBlur *= scale
        style.innerShadowDistance *= scale
        style.outerGlowBlur *= scale
        style.outerGlowSpread *= scale
        style.innerGlowBlur *= scale
        style.innerGlowChoke *= scale
        style.patternOverlayScale *= scale
        style.satinDistance *= scale
        style.satinSize *= scale
        style.bevelSize *= scale
        return style
    }
}

private extension ImageEditorSelection {
    func scaled(scaleX: CGFloat, scaleY: CGFloat, targetSize: CGSize) -> ImageEditorSelection {
        var selection = self
        selection.points = points.map { $0.scaled(scaleX: scaleX, scaleY: scaleY) }
        selection.rasterMask = rasterMask?.resizedNearest(to: targetSize)
        return selection
    }

    func offsetForCanvasResize(oldCanvasSize: CGSize, newCanvasSize: CGSize, offset: CGSize) -> ImageEditorSelection {
        var selection = self
        selection.points = points.map { $0.offset(by: offset) }
        selection.rasterMask = rasterMask?.canvasResized(
            to: newCanvasSize,
            oldCanvasSize: oldCanvasSize,
            offset: offset
        )
        return selection
    }
}

extension ImageEditorSelectionMask {
    func resizedNearest(to targetSize: CGSize) -> ImageEditorSelectionMask {
        let targetWidth = max(1, Int(targetSize.width.rounded()))
        let targetHeight = max(1, Int(targetSize.height.rounded()))
        guard width > 0, height > 0, alpha.count == width * height else {
            return ImageEditorSelectionMask(width: targetWidth, height: targetHeight, alpha: [UInt8](repeating: 0, count: targetWidth * targetHeight))
        }

        var output = [UInt8](repeating: 0, count: targetWidth * targetHeight)
        for y in 0..<targetHeight {
            let sourceY = min(height - 1, Int((CGFloat(y) / CGFloat(targetHeight)) * CGFloat(height)))
            for x in 0..<targetWidth {
                let sourceX = min(width - 1, Int((CGFloat(x) / CGFloat(targetWidth)) * CGFloat(width)))
                output[y * targetWidth + x] = alpha[sourceY * width + sourceX]
            }
        }
        return ImageEditorSelectionMask(width: targetWidth, height: targetHeight, alpha: output)
    }

    func canvasResized(to targetSize: CGSize, oldCanvasSize: CGSize, offset: CGSize) -> ImageEditorSelectionMask {
        let targetWidth = max(1, Int(targetSize.width.rounded()))
        let targetHeight = max(1, Int(targetSize.height.rounded()))
        guard width > 0, height > 0, alpha.count == width * height else {
            return ImageEditorSelectionMask(width: targetWidth, height: targetHeight, alpha: [UInt8](repeating: 0, count: targetWidth * targetHeight))
        }

        let dx = Int(((offset.width / max(oldCanvasSize.width, 1)) * CGFloat(width)).rounded(.toNearestOrAwayFromZero))
        let dy = Int(((offset.height / max(oldCanvasSize.height, 1)) * CGFloat(height)).rounded(.toNearestOrAwayFromZero))
        var output = [UInt8](repeating: 0, count: targetWidth * targetHeight)
        for y in 0..<height {
            let targetY = y + dy
            guard targetY >= 0, targetY < targetHeight else { continue }
            for x in 0..<width {
                let targetX = x + dx
                guard targetX >= 0, targetX < targetWidth else { continue }
                output[targetY * targetWidth + targetX] = alpha[y * width + x]
            }
        }
        return ImageEditorSelectionMask(width: targetWidth, height: targetHeight, alpha: output)
    }
}

extension NSImage {
    func canvasResized(to targetSize: CGSize, oldCanvasSize: CGSize, offset: CGSize) -> NSImage? {
        guard targetSize.width > 0, targetSize.height > 0 else { return nil }
        return NSImage.rendered(size: targetSize) { _ in
            NSColor.clear.setFill()
            CGRect(origin: .zero, size: targetSize).fill()
            draw(
                in: CGRect(origin: CGPoint(x: offset.width, y: offset.height), size: oldCanvasSize),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
        }
    }
}
