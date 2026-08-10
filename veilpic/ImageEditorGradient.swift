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
        guard startPoint.distance(to: endPoint) >= 1 else {
            statusText = L10n.text("imageEditor.status.gradientUnchanged")
            return
        }

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
        guard document.selection?.mayAffect(
            layerFrame: layer.frame,
            expansion: feather
        ) != false else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
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

        let protectedOutput = document.isEffectivelyTransparencyLocked(layer)
            ? (output.preservingAlpha(from: layer.image) ?? output)
            : output
        let normalizedOutput = protectedOutput.normalizedBitmapImage()
        guard !gradientPixelsEqual(normalizedOutput, layer.image) else {
            statusText = L10n.text("imageEditor.status.gradientUnchanged")
            return
        }

        pushUndo()
        document.layers[index].image = normalizedOutput
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
        guard document.selection?.mayAffect(
            layerFrame: document.layers[index].frame,
            expansion: feather
        ) != false else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
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

        let normalizedOutput = output.normalizedBitmapImage()
        guard !gradientPixelsEqual(normalizedOutput, mask) else {
            statusText = L10n.text("imageEditor.status.gradientUnchanged")
            return
        }

        pushUndo()
        document.layers[index].mask = normalizedOutput
        appendHistory(L10n.text("imageEditor.history.layerMaskGradient"))
        statusText = L10n.text("imageEditor.status.gradientApplied")
    }

    private func clampedGradientPoint(_ point: CGPoint, in bounds: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }

    private func gradientPixelsEqual(_ lhs: NSImage, _ rhs: NSImage) -> Bool {
        guard lhs.size == rhs.size,
              let lhsData = lhs.qingtuPNGData(),
              let rhsData = rhs.normalizedBitmapImage().qingtuPNGData()
        else { return false }
        return lhsData == rhsData
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
        let start = CGPoint(
            x: (canvasStart.x - layerFrame.minX) / max(layerFrame.width, 1) * size.width,
            y: (canvasStart.y - layerFrame.minY) / max(layerFrame.height, 1) * size.height
        )
        let end = CGPoint(
            x: (canvasEnd.x - layerFrame.minX) / max(layerFrame.width, 1) * size.width,
            y: (canvasEnd.y - layerFrame.minY) / max(layerFrame.height, 1) * size.height
        )
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
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: size.height) {
                context.drawLinearGradient(
                    gradient,
                    start: start,
                    end: end,
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }
            _ = rect
        }) else { return nil }

        let selectionMask: NSImage?
        if let selection {
            guard let mask = selection.gradientLayerMask(
                layerFrame: layerFrame,
                layerSize: size,
                canvasSize: canvasSize,
                feather: feather
            ) else { return nil }
            selectionMask = mask
        } else {
            selectionMask = nil
        }

        let constrainedGradient: NSImage
        if let selectionMask,
           let maskedGradient = NSImage.rendered(size: size, actions: { rect in
            gradientImage.draw(in: rect, from: CGRect(origin: .zero, size: gradientImage.size), operation: .copy, fraction: 1)
            selectionMask.draw(in: rect, from: CGRect(origin: .zero, size: selectionMask.size), operation: .destinationIn, fraction: 1)
           }) {
            constrainedGradient = maskedGradient
        } else {
            constrainedGradient = gradientImage
        }

        if replacesExistingPixels {
            guard let selectionMask else {
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
                from: CGRect(
                    x: layerFrame.minX,
                    y: canvasSize.height - layerFrame.maxY,
                    width: layerFrame.width,
                    height: layerFrame.height
                ),
                operation: .copy,
                fraction: 1
            )
        }
    }

    func gradientCanvasMask(size: CGSize, feather: CGFloat) -> NSImage? {
        if let rasterMask {
            guard let image = NSImage.selectionMaskImage(
                rasterMask,
                inverted: isInverted,
                targetSize: size
            ) else { return nil }
            guard feather > 0 else { return image }
            return image.blurred(radius: feather) ?? image
        }

        let hardMask = NSImage.rendered(size: size) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            let maskPath = path()

            if isInverted {
                NSColor.white.setFill()
                rect.fill()
            }

            context.saveGState()
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1, y: -1)
            context.setBlendMode(isInverted ? .clear : .normal)
            (isInverted ? NSColor.clear : NSColor.white).setFill()
            maskPath.fill()
            context.restoreGState()
        }
        guard let hardMask, feather > 0 else { return hardMask }
        return hardMask.blurred(radius: feather) ?? hardMask
    }
}
