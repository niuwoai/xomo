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
        guard originalSize.width.isFinite,
              originalSize.height.isFinite,
              originalSize.width > 0,
              originalSize.height > 0
        else {
            statusText = L10n.text("imageEditor.status.resizeInvalid")
            return
        }
        let scaleX = targetSize.width / originalSize.width
        let scaleY = targetSize.height / originalSize.height
        let transformedSlices: [ImageEditorSlice]
        let transformedHotspots: [ImageEditorHotspot]
        do {
            transformedSlices = try document.slices.map { slice in
                try slice.scaledForImageSize(
                    scaleX: scaleX,
                    scaleY: scaleY,
                    sourceCanvasSize: originalSize,
                    targetCanvasSize: targetSize
                )
            }
            transformedHotspots = try document.hotspots.map { hotspot in
                try hotspot.scaledForImageSize(
                    scaleX: scaleX,
                    scaleY: scaleY,
                    targetCanvasSize: targetSize
                )
            }
        } catch {
            statusText = L10n.text("imageEditor.status.resizeInvalid")
            return
        }
        let transformedLayers = document.layers.map { layer in
            layer.scaledForImageSize(scaleX: scaleX, scaleY: scaleY)
        }
        let transformedGuides = scaledGuides(scaleX: scaleX, scaleY: scaleY, targetCanvasSize: targetSize)
        let transformedSelection = document.selection?.scaled(
            scaleX: scaleX,
            scaleY: scaleY,
            targetSize: targetSize
        )
        let transformedSavedSelection = document.savedSelection?.scaled(
            scaleX: scaleX,
            scaleY: scaleY,
            targetSize: targetSize
        )
        let transformedAlphaChannels = document.alphaChannels.map { channel in
            ImageEditorAlphaChannel(
                id: channel.id,
                name: channel.name,
                mask: channel.mask.resizedNearest(to: targetSize)
            )
        }

        pushUndo()
        document.canvasSize = targetSize
        document.layers = transformedLayers
        document.guides = transformedGuides
        document.slices = transformedSlices
        document.hotspots = transformedHotspots
        document.selection = transformedSelection
        document.savedSelection = transformedSavedSelection
        document.alphaChannels = transformedAlphaChannels
        syncExportSettingsForCurrentSliceScope()
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
        guard originalSize.width.isFinite,
              originalSize.height.isFinite,
              originalSize.width > 0,
              originalSize.height > 0
        else {
            statusText = L10n.text("imageEditor.status.resizeInvalid")
            return
        }
        let offset = CGSize(
            width: (targetSize.width - originalSize.width) * anchor.horizontalFactor,
            height: (targetSize.height - originalSize.height) * anchor.verticalFactor
        )
        let hotspotTransform: ImageEditorHotspotCanvasTransform
        do {
            hotspotTransform = try transformedHotspotsForCanvasResize(
                offset: offset,
                targetCanvasSize: targetSize,
                allowsRemoval: true
            )
        } catch {
            statusText = L10n.text("imageEditor.status.resizeInvalid")
            return
        }
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
        document.hotspots = hotspotTransform.hotspots
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
        selectedHotspotID = hotspotTransform.selectedID
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

    var canCropToSelection: Bool {
        cropSelectionRect() != nil
    }

    func cropToSelection() {
        guard document.selection != nil else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard let cropRect = cropSelectionRect() else {
            statusText = L10n.text("imageEditor.status.cropSelectionInvalid")
            return
        }

        crop(to: cropRect, historyTitle: L10n.text("imageEditor.history.cropSelection"))
    }

    func trimTransparentPixels() {
        let width = max(1, Int(document.canvasSize.width.rounded()))
        let height = max(1, Int(document.canvasSize.height.rounded()))
        guard let alphaMask = document.compositedImage.alphaMask(width: width, height: height),
              let bounds = alphaMask.selectedBounds(in: document.canvasSize)
        else {
            statusText = L10n.text("imageEditor.status.trimNoVisiblePixels")
            return
        }

        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        let trimRect = bounds.integral.intersection(canvasBounds)
        guard trimRect.width < document.canvasSize.width || trimRect.height < document.canvasSize.height else {
            statusText = L10n.text("imageEditor.status.trimNoTransparentEdges")
            return
        }

        crop(to: trimRect, historyTitle: L10n.text("imageEditor.history.trim"))
    }

    var canRevealAllLayers: Bool {
        revealAllCanvasRect() != nil
    }

    func revealAllLayers() {
        guard let revealRect = revealAllCanvasRect() else {
            statusText = L10n.text("imageEditor.status.revealAllNoHiddenPixels")
            return
        }
        guard let targetSize = normalizedEditorSize(revealRect.size) else {
            statusText = L10n.text("imageEditor.status.resizeInvalid")
            return
        }

        let originalSize = document.canvasSize
        let offset = CGSize(width: -revealRect.minX, height: -revealRect.minY)
        let hotspotTransform: ImageEditorHotspotCanvasTransform
        do {
            hotspotTransform = try transformedHotspotsForCanvasResize(
                offset: offset,
                targetCanvasSize: targetSize,
                allowsRemoval: false
            )
        } catch {
            statusText = L10n.text("imageEditor.status.resizeInvalid")
            return
        }
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
        document.hotspots = hotspotTransform.hotspots
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
        selectedHotspotID = hotspotTransform.selectedID
        canvasOffset = .zero
        syncSizeControlsFromDocument()
        appendHistory(L10n.text("imageEditor.history.revealAll"))
    }

    func crop(to rect: CGRect) {
        crop(to: rect, historyTitle: L10n.text("imageEditor.history.crop"))
    }

    private func crop(to rect: CGRect, historyTitle: String) {
        let originalSize = document.canvasSize
        let bounded = ImageEditorCropGeometry.committedPixelBounds(
            for: rect,
            canvasSize: originalSize
        )
        guard bounded.width >= 8,
              bounded.height >= 8,
              bounded.width < originalSize.width || bounded.height < originalSize.height
        else {
            statusText = L10n.text("imageEditor.status.resizeInvalid")
            return
        }

        let targetSize = bounded.size
        let offset = CGSize(width: -bounded.minX, height: -bounded.minY)
        let hotspotTransform: ImageEditorHotspotCanvasTransform
        do {
            hotspotTransform = try transformedHotspotsForCanvasResize(
                offset: offset,
                targetCanvasSize: targetSize,
                allowsRemoval: true
            )
        } catch {
            statusText = L10n.text("imageEditor.status.resizeInvalid")
            return
        }
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
        document.hotspots = hotspotTransform.hotspots
        document.selection = .fullCanvas(size: targetSize)
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
        selectedHotspotID = hotspotTransform.selectedID
        canvasOffset = .zero
        syncSizeControlsFromDocument()
        appendHistory(historyTitle)
    }

    private func normalizedEditorSize(_ size: CGSize) -> CGSize? {
        let width = CGFloat(size.width.rounded())
        let height = CGFloat(size.height.rounded())
        guard width >= 8, height >= 8, width <= 12_000, height <= 12_000 else { return nil }
        return CGSize(width: width, height: height)
    }

    private func transformedHotspotsForCanvasResize(
        offset: CGSize,
        targetCanvasSize: CGSize,
        allowsRemoval: Bool
    ) throws -> ImageEditorHotspotCanvasTransform {
        var hotspots: [ImageEditorHotspot] = []
        hotspots.reserveCapacity(document.hotspots.count)
        for hotspot in document.hotspots {
            guard let transformed = try hotspot.offsetForCanvasResize(
                offset: offset,
                targetCanvasSize: targetCanvasSize
            ) else {
                guard allowsRemoval else {
                    throw ImageEditorHotspotCanvasTransformError.unexpectedRemoval
                }
                continue
            }
            hotspots.append(transformed)
        }

        let selectedID: UUID?
        if let selectedHotspotID {
            selectedID = hotspots.contains(where: { $0.id == selectedHotspotID })
                ? selectedHotspotID
                : hotspots.first?.id
        } else {
            selectedID = nil
        }
        return ImageEditorHotspotCanvasTransform(
            hotspots: hotspots,
            selectedID: selectedID
        )
    }

    private func revealAllCanvasRect() -> CGRect? {
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize).integral
        let contentBounds = document.layers
            .filter { document.shouldComposite($0) }
            .map { $0.renderedCompositingFrame(globalLightAngle: document.globalLightAngle).standardized.integral }
            .filter { $0.width > 0.1 && $0.height > 0.1 }
            .reduce(nil) { bounds, frame -> CGRect? in
                bounds?.union(frame) ?? frame
            }

        guard let contentBounds else { return nil }
        let revealRect = canvasBounds.union(contentBounds).integral
        guard revealRect.width > canvasBounds.width || revealRect.height > canvasBounds.height else { return nil }
        return revealRect
    }

    private func cropSelectionRect() -> CGRect? {
        guard let selection = document.selection else { return nil }
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        guard let selectedBounds = selection.effectiveSelectedBounds(in: document.canvasSize) else { return nil }
        let rect = selectedBounds.standardized.intersection(canvasBounds).integral
        guard rect.width >= 8,
              rect.height >= 8,
              rect.width < canvasBounds.width || rect.height < canvasBounds.height
        else { return nil }
        return rect
    }
}

private struct ImageEditorHotspotCanvasTransform {
    let hotspots: [ImageEditorHotspot]
    let selectedID: UUID?
}

private enum ImageEditorHotspotCanvasTransformError: Error {
    case unexpectedRemoval
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
        case .solidColorFill:
            layer.image = NSImage.transparent(size: targetLayerSize)
        case .patternFill:
            layer.image = NSImage.transparent(size: targetLayerSize)
        case .gradientFill:
            layer.image = NSImage.transparent(size: targetLayerSize)
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
        if content.boxHeight > 0 {
            content.boxHeight = max(1, boxHeight * scaleY)
        }
        return content
    }
}

private extension ImageEditorShapeContent {
    func scaled(scaleX: CGFloat, scaleY: CGFloat) -> ImageEditorShapeContent {
        let averageScale = (scaleX + scaleY) / 2
        var content = self
        content.strokeWidth = max(Self.minimumStrokeWidth, strokeWidth * averageScale)
        content.cornerRadius = max(0, cornerRadius * averageScale)
        content.cornerRadii = cornerRadii?.scaled(by: averageScale)
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

extension ImageEditorLayerStyle {
    func scaled(by scale: CGFloat) -> ImageEditorLayerStyle {
        var style = self
        style.strokeWidth *= scale
        style.strokePatternScale *= scale
        style.strokePatternOffset = CGSize(
            width: strokePatternOffset.width * scale,
            height: strokePatternOffset.height * scale
        )
        style.shadowBlur *= scale
        style.shadowSpread *= scale
        style.shadowDistance *= scale
        style.shadowOffset = CGSize(width: shadowOffset.width * scale, height: shadowOffset.height * scale)
        style.innerShadowBlur *= scale
        style.innerShadowChoke *= scale
        style.innerShadowDistance *= scale
        style.outerGlowBlur *= scale
        style.outerGlowSpread *= scale
        style.innerGlowBlur *= scale
        style.innerGlowChoke *= scale
        style.patternOverlayScale *= scale
        style.patternOverlayOffset = CGSize(
            width: patternOverlayOffset.width * scale,
            height: patternOverlayOffset.height * scale
        )
        style.satinDistance *= scale
        style.satinSize *= scale
        style.bevelSize *= scale
        style.bevelSoften *= scale
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
