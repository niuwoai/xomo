//
//  LosslessImageOptimizer.swift
//  veilpic
//
//  Created by Codex on 2026/7/6.
//

import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct LosslessOptimizationResult: Sendable {
    let originalData: Data
    let optimizedData: Data

    var savedBytes: Int {
        max(0, originalData.count - optimizedData.count)
    }

    var didReduceSize: Bool {
        optimizedData.count < originalData.count
    }

    var savingsText: String {
        guard didReduceSize else {
            return L10n.text("losslessCompression.result.noSavings")
        }

        let original = ByteCountFormatter.string(fromByteCount: Int64(originalData.count), countStyle: .file)
        let optimized = ByteCountFormatter.string(fromByteCount: Int64(optimizedData.count), countStyle: .file)
        let percent = Double(savedBytes) / Double(max(originalData.count, 1)) * 100
        return L10n.format("losslessCompression.result.saved", original, optimized, percent)
    }
}

enum LosslessImageOptimizer {
    static func optimizedPNGData(from image: NSImage) -> LosslessOptimizationResult? {
        guard let baseData = image.qingtuPNGData() else {
            return nil
        }

        return optimizedPNGData(baseData, image: image)
    }

    static func optimizedPNGData(_ pngData: Data, image: NSImage? = nil) -> LosslessOptimizationResult {
        let candidates = pngCandidates(from: pngData, image: image)
        let best = candidates.min(by: { $0.count < $1.count }) ?? pngData
        return LosslessOptimizationResult(
            originalData: pngData,
            optimizedData: best.count < pngData.count ? best : pngData
        )
    }

    private static func pngCandidates(from pngData: Data, image: NSImage?) -> [Data] {
        var candidates = [pngData]

        if let image {
            candidates.append(contentsOf: pngCandidates(from: image))
        }

        if let source = CGImageSourceCreateWithData(pngData as CFData, nil),
           let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            candidates.append(contentsOf: pngCandidates(from: cgImage))
        }

        return candidates
    }

    private static func pngCandidates(from image: NSImage) -> [Data] {
        var candidates: [Data] = []

        if let tiffRepresentation = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffRepresentation) {
            candidates.append(contentsOf: [
                bitmap.representation(using: .png, properties: [:]),
                bitmap.representation(using: .png, properties: [.interlaced: false]),
                bitmap.representation(using: .png, properties: [.compressionFactor: 1.0])
            ].compactMap { $0 })
        }

        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            candidates.append(contentsOf: pngCandidates(from: cgImage))
        }

        return candidates
    }

    private static func pngCandidates(from cgImage: CGImage) -> [Data] {
        [
            pngData(from: cgImage, properties: [:]),
            pngData(
                from: cgImage,
                properties: [
                    kCGImagePropertyPNGDictionary as String: [
                        kCGImagePropertyPNGInterlaceType as String: 0
                    ]
                ]
            )
        ].compactMap { $0 }
    }

    private static func pngData(from cgImage: CGImage, properties: [String: Any]) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }
}
