//
//  PasteboardImageReader.swift
//  veilpic
//
//  Created by Codex on 2026/5/20.
//

import AppKit
import UniformTypeIdentifiers

extension NSPasteboard {
    func readImage() -> NSImage? {
        if let image = readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            return image
        }

        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = data(forType: type), let image = NSImage(data: data) {
                return image
            }
        }

        return nil
    }
}

extension NSItemProvider {
    func loadImage() async -> NSImage? {
        if hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let image = await loadFileImage() {
            return image
        }

        return await withCheckedContinuation { continuation in
            loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data, let image = NSImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    private func loadFileImage() async -> NSImage? {
        await withCheckedContinuation { continuation in
            loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard
                    let data,
                    let url = URL(dataRepresentation: data, relativeTo: nil),
                    let image = NSImage(contentsOf: url)
                else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }
}
