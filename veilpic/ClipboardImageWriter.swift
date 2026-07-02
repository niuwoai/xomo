//
//  ClipboardImageWriter.swift
//  veilpic
//
//  Created by Codex on 2026/7/2.
//

import AppKit
import Foundation

enum ClipboardImageWriter {
    static func copy(_ image: NSImage, preferredFileName: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let imageItem = NSPasteboardItem()
        var hasImageData = false
        let pngData = image.qingtuPNGData()

        if let pngData {
            imageItem.setData(pngData, forType: .png)
            hasImageData = true
        }
        if let tiffData = image.tiffRepresentation {
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

    private static func clipboardCacheDirectory() -> URL {
        let base = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(".QingtuClipboard", isDirectory: true)
    }

    private static func sanitizedFileName(_ preferredFileName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let sanitized = preferredFileName
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
            .split(separator: "-")
            .joined(separator: "-")
        let basename = sanitized.isEmpty ? "QingtuClipboard" : sanitized
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
