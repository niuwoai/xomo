//
//  ClipboardImageWriter.swift
//  veilpic
//
//  Created by Codex on 2026/7/2.
//

import AppKit
import Foundation

enum XomoClipboardLayerPayload {
    static let pasteboardType = NSPasteboard.PasteboardType("im.some.xomo.layer-frame")

    private struct Frame: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double

        init(_ rect: CGRect) {
            x = rect.minX
            y = rect.minY
            width = rect.width
            height = rect.height
        }

        var rect: CGRect {
            CGRect(x: x, y: y, width: width, height: height)
        }
    }

    static func data(for frame: CGRect) -> Data? {
        let normalized = frame.standardized
        guard normalized.width > 0,
              normalized.height > 0,
              normalized.minX.isFinite,
              normalized.minY.isFinite,
              normalized.width.isFinite,
              normalized.height.isFinite
        else { return nil }
        return try? JSONEncoder().encode(Frame(normalized))
    }

    static func frame(from pasteboard: NSPasteboard) -> CGRect? {
        guard let data = pasteboard.data(forType: pasteboardType),
              let frame = try? JSONDecoder().decode(Frame.self, from: data)
        else { return nil }
        let normalized = frame.rect.standardized
        guard normalized.width > 0,
              normalized.height > 0,
              normalized.minX.isFinite,
              normalized.minY.isFinite,
              normalized.width.isFinite,
              normalized.height.isFinite
        else { return nil }
        return normalized
    }
}

enum ClipboardImageWriter {
    static let clipboardCacheFolderName = "im.some.xomo/Clipboard"

    static func copy(_ image: NSImage, preferredFileName: String, optimizeLosslessly: Bool = false) -> Bool {
        let pngData = image.qingtuPNGData().map { data in
            optimizeLosslessly
                ? LosslessImageOptimizer.optimizedPNGData(data, image: image).optimizedData
                : data
        }
        return copyPNGData(pngData, image: image, preferredFileName: preferredFileName)
    }

    static func copyPNGData(_ pngData: Data?, image: NSImage? = nil, preferredFileName: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let imageItem = NSPasteboardItem()
        var hasImageData = false
        if let pngData {
            imageItem.setData(pngData, forType: .png)
            hasImageData = true
        }
        if let tiffData = image?.tiffRepresentation {
            imageItem.setData(tiffData, forType: .tiff)
            hasImageData = true
        }

        var objects: [NSPasteboardWriting] = []
        if hasImageData {
            objects.append(imageItem)
        }
        if let pngData, let fileURL = writeClipboardPNG(data: pngData, preferredFileName: preferredFileName) {
            objects.append(fileURL as NSURL)
        }

        guard !objects.isEmpty else {
            guard let image else { return false }
            return pasteboard.writeObjects([image])
        }
        return pasteboard.writeObjects(objects)
    }

    private static func writeClipboardPNG(data: Data, preferredFileName: String) -> URL? {
        let directory = clipboardCacheDirectory()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            cleanupClipboardCache(in: directory)
            let url = directory.appendingPathComponent(sanitizedFileName(preferredFileName))
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func clipboardCacheDirectory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent(clipboardCacheFolderName, isDirectory: true)
    }

    private static func sanitizedFileName(_ preferredFileName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let sanitized = preferredFileName
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
            .split(separator: "-")
            .joined(separator: "-")
        let basename = sanitized.isEmpty ? "musepicClipboard" : sanitized
        if basename.lowercased().hasSuffix(".png") {
            return basename
        }
        return "\(basename).png"
    }

    private static func cleanupClipboardCache(in directory: URL) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let sorted = urls.sorted { lhs, rhs in
            let leftDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rightDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return leftDate > rightDate
        }
        for staleURL in sorted.dropFirst(30) {
            try? FileManager.default.removeItem(at: staleURL)
        }
    }
}
