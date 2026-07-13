//
//  ImageEditorImageComparison.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/13.
//

import AppKit
import CoreGraphics

enum ImageEditorTestPixelTolerance {
    static let rasterizedMerge = 16
    static let undoRoundTrip = 8
    static let clippedAdjustmentMerge = 40
}

func imageEditorMaximumPixelDifference(_ lhs: NSImage, _ rhs: NSImage) -> Int {
    guard lhs.size == rhs.size else { return .max }
    let width = Int(lhs.size.width.rounded())
    let height = Int(lhs.size.height.rounded())
    guard width > 0,
          height > 0,
          let leftPixels = imageEditorRGBABytes(lhs, width: width, height: height),
          let rightPixels = imageEditorRGBABytes(rhs, width: width, height: height)
    else { return .max }

    var maximumDifference = 0
    for (left, right) in zip(leftPixels, rightPixels) {
        maximumDifference = max(maximumDifference, abs(Int(left) - Int(right)))
    }
    return maximumDifference
}

private func imageEditorRGBABytes(
    _ image: NSImage,
    width: Int,
    height: Int
) -> [UInt8]? {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return nil
    }
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
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pixels
}
