//
//  ImageEditorSelectionBoolean.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

extension ImageEditorSelection {
    static func combined(
        current: ImageEditorSelection?,
        candidate: ImageEditorSelection,
        mode: ImageEditorSelectionMode,
        canvasSize: CGSize
    ) -> ImageEditorSelection? {
        guard let current else {
            switch mode {
            case .replace, .add:
                return candidate
            case .subtract, .intersect:
                return nil
            }
        }

        guard mode != .replace else { return candidate }
        guard let currentMask = current.rasterizedMask(canvasSize: canvasSize),
              let candidateMask = candidate.rasterizedMask(canvasSize: canvasSize),
              let outputMask = currentMask.combined(with: candidateMask, mode: mode),
              let bounds = outputMask.selectedBounds(in: canvasSize)
        else { return nil }

        return .raster(mask: outputMask, bounds: bounds)
    }

    func rasterizedMask(canvasSize: CGSize) -> ImageEditorSelectionMask? {
        let width = max(1, Int(canvasSize.width.rounded()))
        let height = max(1, Int(canvasSize.height.rounded()))

        if let rasterMask,
           let image = NSImage.selectionMaskImage(
            rasterMask,
            inverted: isInverted,
            targetSize: CGSize(width: width, height: height)
           ) {
            return image.alphaPlaneMask(width: width, height: height)
        }

        let image = NSImage.rendered(size: CGSize(width: width, height: height)) { rect in
            let selectionPath = self.path()
            if isInverted {
                NSColor.white.setFill()
                rect.fill()
                guard let context = NSGraphicsContext.current?.cgContext else { return }
                context.saveGState()
                context.setBlendMode(.clear)
                NSColor.clear.setFill()
                selectionPath.fill()
                context.restoreGState()
            } else {
                NSColor.white.setFill()
                selectionPath.fill()
            }
        }
        return image?.alphaPlaneMask(width: width, height: height)
    }
}

private extension ImageEditorSelectionMask {
    func combined(with other: ImageEditorSelectionMask, mode: ImageEditorSelectionMode) -> ImageEditorSelectionMask? {
        guard width == other.width, height == other.height, alpha.count == other.alpha.count else { return nil }

        var output = [UInt8](repeating: 0, count: alpha.count)
        for index in alpha.indices {
            let current = alpha[index]
            let candidate = other.alpha[index]
            switch mode {
            case .replace:
                output[index] = candidate
            case .add:
                output[index] = max(current, candidate)
            case .subtract:
                output[index] = min(current, UInt8.max - candidate)
            case .intersect:
                output[index] = min(current, candidate)
            }
        }

        return ImageEditorSelectionMask(width: width, height: height, alpha: output)
    }

    func selectedBounds(in canvasSize: CGSize) -> CGRect? {
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                guard alpha[y * width + x] > 0 else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        let scaleX = canvasSize.width / CGFloat(width)
        let scaleY = canvasSize.height / CGFloat(height)
        return CGRect(
            x: CGFloat(minX) * scaleX,
            y: CGFloat(minY) * scaleY,
            width: CGFloat(maxX - minX + 1) * scaleX,
            height: CGFloat(maxY - minY + 1) * scaleY
        )
    }
}

private extension NSImage {
    func alphaPlaneMask(width: Int, height: Int) -> ImageEditorSelectionMask? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
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
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                alpha[y * width + x] = pixels[offset + 3]
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }
}
