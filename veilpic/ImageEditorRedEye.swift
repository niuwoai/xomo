//
//  ImageEditorRedEye.swift
//  veilpic
//

import AppKit
import Foundation

extension NSImage {
    func withRedEyeReduction(at point: CGPoint, radius: CGFloat, opacity: CGFloat) -> NSImage? {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerRow = width * 4
        guard var pixels = redEyePixels(width: width, height: height, bytesPerRow: bytesPerRow) else { return nil }

        let centerX = max(0, min(width - 1, Int((point.x / max(size.width, 1) * CGFloat(width)).rounded())))
        let centerY = max(0, min(height - 1, Int((point.y / max(size.height, 1) * CGFloat(height)).rounded())))
        let pixelRadius = max(1, Int((radius / max(size.width, 1) * CGFloat(width)).rounded()))
        let clampedOpacity = max(0, min(1, opacity))
        let radiusSquared = pixelRadius * pixelRadius

        for y in max(0, centerY - pixelRadius)...min(height - 1, centerY + pixelRadius) {
            for x in max(0, centerX - pixelRadius)...min(width - 1, centerX + pixelRadius) {
                let deltaX = x - centerX
                let deltaY = y - centerY
                let distanceSquared = deltaX * deltaX + deltaY * deltaY
                guard distanceSquared <= radiusSquared else { continue }

                let offset = y * bytesPerRow + x * 4
                let red = CGFloat(pixels[offset])
                let green = CGFloat(pixels[offset + 1])
                let blue = CGFloat(pixels[offset + 2])
                guard red > green * 1.15, red > blue * 1.15 else { continue }

                let falloff = 1 - sqrt(CGFloat(distanceSquared) / CGFloat(radiusSquared))
                let neutral = (green + blue) / 2
                let replacement = red + (neutral - red) * clampedOpacity * falloff
                pixels[offset] = UInt8(max(0, min(255, replacement.rounded())))
            }
        }

        var outputPixels = pixels
        guard let context = CGContext(
            data: &outputPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else { return nil }
        return NSImage(cgImage: image, size: size)
    }

    private func redEyePixels(width: Int, height: Int, bytesPerRow: Int) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }
}
