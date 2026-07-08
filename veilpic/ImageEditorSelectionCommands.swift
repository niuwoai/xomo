//
//  ImageEditorSelectionCommands.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

@MainActor
extension ImageEditorViewModel {
    var canLoadSelectionFromLayerTransparency: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer
        else { return false }
        return !layer.isGroup && !layer.isAdjustment && !layer.isFilter
    }

    var hasSavedSelection: Bool {
        document.savedSelection != nil
    }

    func loadSelectionFromLayerTransparency() {
        guard canLoadSelectionFromLayerTransparency,
              let index = document.selectedLayerIndex,
              let selection = transparencySelection(forLayerAt: index)
        else {
            statusText = L10n.text("imageEditor.status.selectionFromLayerFailed")
            return
        }

        pushUndo()
        document.selection = selection
        appendHistory(L10n.text("imageEditor.history.selectionFromLayer"))
        statusText = L10n.text("imageEditor.status.selectionFromLayer")
    }

    func saveCurrentSelection() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }

        pushUndo()
        document.savedSelection = selection
        appendHistory(L10n.text("imageEditor.history.selectionSaved"))
        statusText = L10n.text("imageEditor.status.selectionSaved")
    }

    func restoreSavedSelection() {
        guard let selection = document.savedSelection else {
            statusText = L10n.text("imageEditor.status.noSavedSelection")
            return
        }

        pushUndo()
        document.selection = selection
        appendHistory(L10n.text("imageEditor.history.selectionRestored"))
        statusText = L10n.text("imageEditor.status.selectionRestored")
    }

    private func transparencySelection(forLayerAt index: Int) -> ImageEditorSelection? {
        guard document.layers.indices.contains(index) else { return nil }
        let layer = document.layers[index]
        guard let image = NSImage.rendered(size: document.canvasSize, actions: { _ in
            if layer.isClippingMask,
               let clippedImage = document.clippedCompositingImage(forLayerAt: index) {
                clippedImage.draw(
                    in: CGRect(origin: .zero, size: document.canvasSize),
                    from: CGRect(origin: .zero, size: document.canvasSize),
                    operation: .sourceOver,
                    fraction: 1
                )
            } else {
                let compositingImage = layer.compositingImage
                compositingImage.draw(
                    in: layer.compositingFrame,
                    from: CGRect(origin: .zero, size: compositingImage.size),
                    operation: .sourceOver,
                    fraction: 1
                )
            }
        }) else { return nil }
        return image.alphaSelection(threshold: 8)
    }
}

extension NSImage {
    func alphaSelection(threshold: UInt8) -> ImageEditorSelection? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = max(1, cgImage.width)
        let height = max(1, cgImage.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var alpha = [UInt8](repeating: 0, count: width * height)
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = y * bytesPerRow + x * bytesPerPixel
                let value = pixels[pixelOffset + 3]
                let selected = value > threshold ? UInt8.max : 0
                alpha[y * width + x] = selected
                guard selected > 0 else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        let scaleX = size.width / CGFloat(width)
        let scaleY = size.height / CGFloat(height)
        let bounds = CGRect(
            x: CGFloat(minX) * scaleX,
            y: CGFloat(minY) * scaleY,
            width: CGFloat(maxX - minX + 1) * scaleX,
            height: CGFloat(maxY - minY + 1) * scaleY
        )
        return .raster(
            mask: ImageEditorSelectionMask(width: width, height: height, alpha: alpha),
            bounds: bounds
        )
    }

    static func selectionMaskImage(
        _ mask: ImageEditorSelectionMask,
        inverted: Bool,
        targetSize: CGSize
    ) -> NSImage? {
        let values = inverted ? mask.alpha.map { UInt8.max - $0 } : mask.alpha
        guard let sourceImage = NSImage.alphaMaskImage(width: mask.width, height: mask.height, alpha: values) else {
            return nil
        }
        guard sourceImage.size == targetSize else {
            return NSImage.rendered(size: targetSize) { _ in
                sourceImage.draw(
                    in: CGRect(origin: .zero, size: targetSize),
                    from: CGRect(origin: .zero, size: sourceImage.size),
                    operation: .copy,
                    fraction: 1
                )
            }
        }
        return sourceImage
    }

    static func alphaMaskImage(width: Int, height: Int, alpha: [UInt8]) -> NSImage? {
        let width = max(1, width)
        let height = max(1, height)
        guard alpha.count == width * height else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        for y in 0..<height {
            for x in 0..<width {
                let alphaValue = alpha[y * width + x]
                let offset = y * bytesPerRow + x * bytesPerPixel
                pixels[offset] = UInt8.max
                pixels[offset + 1] = UInt8.max
                pixels[offset + 2] = UInt8.max
                pixels[offset + 3] = alphaValue
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else { return nil }

        let image = NSImage(size: CGSize(width: width, height: height))
        image.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
        return image
    }
}
