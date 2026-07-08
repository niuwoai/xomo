//
//  ImageEditorGradient.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

@MainActor
extension ImageEditorViewModel {
    func drawGradient(from start: CGPoint?, to end: CGPoint?) {
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        let startPoint = clampedGradientPoint(start ?? CGPoint(x: 0, y: document.canvasSize.height), in: canvasBounds)
        let endPoint = clampedGradientPoint(end ?? CGPoint(x: document.canvasSize.width, y: 0), in: canvasBounds)
        guard startPoint.distance(to: endPoint) > 1 else { return }

        if isEditingLayerMask {
            drawGradientOnSelectedLayerMask(from: startPoint, to: endPoint)
            return
        }

        guard selectedLayerCount == 1,
              let index = document.selectedLayerIndex
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let layer = document.layers[index]
        guard !layer.isGroup,
              !layer.isAdjustment,
              !layer.isFilter,
              !layer.isText,
              !document.isEffectivelyPixelsLocked(layer)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        guard let output = layer.image.withLinearGradient(
            from: startPoint,
            to: endPoint,
            layerFrame: layer.frame,
            canvasSize: document.canvasSize,
            startColor: foregroundColor,
            endColor: backgroundColor,
            opacity: opacity,
            selection: document.selection,
            feather: feather
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].image = output.normalizedBitmapImage()
        appendHistory(L10n.text("imageEditor.history.gradient"))
        statusText = L10n.text("imageEditor.status.gradientApplied")
    }

    func addGradient() {
        drawGradient(from: nil, to: nil)
    }

    private func drawGradientOnSelectedLayerMask(from start: CGPoint, to end: CGPoint) {
        guard selectedLayerCount == 1,
              let index = document.selectedLayerIndex
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard !document.isEffectivelyLocked(document.layers[index]) else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        guard let mask = document.layers[index].mask else {
            statusText = L10n.text("imageEditor.status.noLayerMask")
            isEditingLayerMask = false
            return
        }
        guard let output = mask.withLinearGradient(
            from: start,
            to: end,
            layerFrame: document.layers[index].frame,
            canvasSize: document.canvasSize,
            startColor: .white,
            endColor: .clear,
            opacity: opacity,
            selection: document.selection,
            feather: feather,
            replacesExistingPixels: true
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].mask = output.normalizedBitmapImage()
        appendHistory(L10n.text("imageEditor.history.layerMaskGradient"))
        statusText = L10n.text("imageEditor.status.gradientApplied")
    }

    private func clampedGradientPoint(_ point: CGPoint, in bounds: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }
}

private extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }
}

private extension NSImage {
    func withLinearGradient(
        from canvasStart: CGPoint,
        to canvasEnd: CGPoint,
        layerFrame: CGRect,
        canvasSize: CGSize,
        startColor: NSColor,
        endColor: NSColor,
        opacity: CGFloat,
        selection: ImageEditorSelection?,
        feather: CGFloat,
        replacesExistingPixels: Bool = false
    ) -> NSImage? {
        let start = CGPoint(x: canvasStart.x - layerFrame.minX, y: canvasStart.y - layerFrame.minY)
        let end = CGPoint(x: canvasEnd.x - layerFrame.minX, y: canvasEnd.y - layerFrame.minY)
        guard let gradientImage = NSImage.rendered(size: size, actions: { rect in
            guard let context = NSGraphicsContext.current?.cgContext,
                  let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [
                        startColor.multiplyingAlpha(by: opacity).cgColor,
                        endColor.multiplyingAlpha(by: opacity).cgColor
                    ] as CFArray,
                    locations: [0, 1]
                  )
            else { return }
            context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            _ = rect
        }) else { return nil }

        let constrainedGradient: NSImage
        if let selection,
           let selectionMask = selection.gradientLayerMask(
            layerFrame: layerFrame,
            layerSize: size,
            canvasSize: canvasSize,
            feather: feather
           ),
           let maskedGradient = NSImage.rendered(size: size, actions: { rect in
            gradientImage.draw(in: rect, from: CGRect(origin: .zero, size: gradientImage.size), operation: .copy, fraction: 1)
            selectionMask.draw(in: rect, from: CGRect(origin: .zero, size: selectionMask.size), operation: .destinationIn, fraction: 1)
           }) {
            constrainedGradient = maskedGradient
        } else {
            constrainedGradient = gradientImage
        }

        if replacesExistingPixels {
            guard let selectionMask = selection?.gradientLayerMask(
                layerFrame: layerFrame,
                layerSize: size,
                canvasSize: canvasSize,
                feather: feather
            ) else {
                return constrainedGradient
            }
            return NSImage.rendered(size: size) { rect in
                draw(in: rect, from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
                selectionMask.draw(in: rect, from: CGRect(origin: .zero, size: selectionMask.size), operation: .destinationOut, fraction: 1)
                constrainedGradient.draw(in: rect, from: CGRect(origin: .zero, size: constrainedGradient.size), operation: .sourceOver, fraction: 1)
            }
        }

        return NSImage.rendered(size: size) { rect in
            draw(in: rect, from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            constrainedGradient.draw(in: rect, from: CGRect(origin: .zero, size: constrainedGradient.size), operation: .sourceOver, fraction: 1)
        }
    }

}

private extension NSColor {
    func multiplyingAlpha(by opacity: CGFloat) -> NSColor {
        let color = usingColorSpace(.deviceRGB) ?? self
        return color.withAlphaComponent(color.alphaComponent * max(0, min(1, opacity)))
    }
}

private extension ImageEditorSelection {
    func gradientLayerMask(layerFrame: CGRect, layerSize: CGSize, canvasSize: CGSize, feather: CGFloat) -> NSImage? {
        guard layerSize.width > 0,
              layerSize.height > 0,
              layerFrame.width > 0,
              layerFrame.height > 0,
              let canvasMask = gradientCanvasMask(size: canvasSize, feather: feather)
        else { return nil }

        return NSImage.rendered(size: layerSize) { _ in
            canvasMask.draw(
                in: CGRect(origin: .zero, size: layerSize),
                from: layerFrame,
                operation: .copy,
                fraction: 1
            )
        }
    }

    func gradientCanvasMask(size: CGSize, feather: CGFloat) -> NSImage? {
        if let rasterMask,
           let image = NSImage.selectionMaskImage(rasterMask, inverted: isInverted, targetSize: size) {
            guard feather > 0 else { return image }
            return image.blurred(radius: feather) ?? image
        }

        let hardMask = NSImage.rendered(size: size) { rect in
            let maskPath = self.path()
            if isInverted {
                NSColor.white.setFill()
                rect.fill()
                guard let context = NSGraphicsContext.current?.cgContext else { return }
                context.saveGState()
                context.setBlendMode(.clear)
                NSColor.clear.setFill()
                maskPath.fill()
                context.restoreGState()
            } else {
                NSColor.white.setFill()
                maskPath.fill()
            }
        }
        guard let hardMask, feather > 0 else { return hardMask }
        return hardMask.blurred(radius: feather) ?? hardMask
    }
}
