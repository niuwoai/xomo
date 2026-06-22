//
//  ImageVariantBuilder.swift
//  veilpic
//
//  Created by Codex on 2026/5/20.
//

import AppKit
import ImageIO
import UniformTypeIdentifiers

final class ImageVariantBuilder {
    func buildVariants(from image: NSImage, basename: String) -> [GeneratedImageVariant] {
        var variants: [GeneratedImageVariant] = []

        if let png = image.pngData() {
            variants.append(.init(kind: .original, filename: "\(basename)-original.png", data: png, contentType: "image/png"))
        }

        if let compressed = image.jpegData(maxPixelWidth: 1600, compression: 0.78) {
            variants.append(.init(kind: .compressed, filename: "\(basename)-compressed.jpg", data: compressed, contentType: "image/jpeg"))
        }

        if let thumbnail = image.jpegData(maxPixelWidth: 480, compression: 0.72) {
            variants.append(.init(kind: .thumbnail, filename: "\(basename)-thumb.jpg", data: thumbnail, contentType: "image/jpeg"))
        }

        if let webp = image.webpData(maxPixelWidth: 1600, compression: 0.78) {
            variants.append(.init(kind: .webpReference, filename: "\(basename)-original.webp", data: webp, contentType: "image/webp"))
        }

        return variants
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation)
        else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    func jpegData(maxPixelWidth: CGFloat, compression: CGFloat) -> Data? {
        guard let resized = resized(maxPixelWidth: maxPixelWidth),
              let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else {
            return nil
        }

        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compression])
    }

    func webpData(maxPixelWidth: CGFloat, compression: CGFloat) -> Data? {
        let writableTypes = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        guard writableTypes.contains(UTType.webP.identifier) else {
            return nil
        }

        guard let resized = resized(maxPixelWidth: maxPixelWidth),
              let cgImage = resized.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.webP.identifier as CFString, 1, nil) else {
            return nil
        }

        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: compression] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }

    func resized(maxPixelWidth: CGFloat) -> NSImage? {
        let currentSize = size
        guard currentSize.width > maxPixelWidth else { return self }

        let ratio = maxPixelWidth / currentSize.width
        let targetSize = NSSize(width: maxPixelWidth, height: currentSize.height * ratio)
        let image = NSImage(size: targetSize)
        image.lockFocus()
        draw(in: NSRect(origin: .zero, size: targetSize), from: NSRect(origin: .zero, size: currentSize), operation: .copy, fraction: 1)
        image.unlockFocus()
        return image
    }
}
