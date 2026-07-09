//
//  ImageEditorChannels.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit

enum ImageEditorChannelPreview: String, CaseIterable, Identifiable {
    case composite
    case red
    case green
    case blue
    case alpha

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.channel.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .composite:
            "circle.grid.cross"
        case .red:
            "r.circle"
        case .green:
            "g.circle"
        case .blue:
            "b.circle"
        case .alpha:
            "a.circle"
        }
    }
}

enum ImageEditorLayerPanelTab: String, CaseIterable, Identifiable {
    case layers
    case channels
    case comps

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.panelTab.\(rawValue)")
    }
}

@MainActor
extension ImageEditorViewModel {
    var canSaveSelectionAsAlphaChannel: Bool {
        guard let mask = document.selection?.rasterizedMask(canvasSize: document.canvasSize) else { return false }
        return mask.selectedBounds(in: document.canvasSize) != nil
    }

    var canSaveSelectedLayerMaskAsAlphaChannel: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer
        else { return false }
        return layer.mask != nil
    }

    var canApplyAlphaChannelToSelectedLayerMask: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer
        else { return false }
        return !document.isEffectivelyLocked(layer)
    }

    func loadSelectionFromChannel(_ channel: ImageEditorChannelPreview) {
        guard let selection = currentImage.channelSelection(channel, canvasSize: document.canvasSize) else {
            statusText = L10n.format("imageEditor.status.channelSelectionEmpty", channel.title)
            return
        }

        applySelectionCandidate(selection, replaceHistoryKey: "imageEditor.history.selectionFromChannel")
        if document.selection != nil {
            statusText = L10n.format("imageEditor.status.channelSelection", channel.title)
        }
    }

    func saveSelectionAsAlphaChannel() {
        guard let mask = document.selection?.rasterizedMask(canvasSize: document.canvasSize),
              mask.selectedBounds(in: document.canvasSize) != nil
        else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }

        pushUndo()
        let nextIndex = document.alphaChannels.count + 1
        document.alphaChannels.append(
            ImageEditorAlphaChannel(
                name: L10n.format("imageEditor.channel.alphaChannelName", nextIndex),
                mask: mask
            )
        )
        appendHistory(L10n.text("imageEditor.history.alphaChannelSave"))
        statusText = L10n.text("imageEditor.status.alphaChannelSaved")
    }

    func saveSelectedLayerMaskAsAlphaChannel() {
        guard let layer = document.selectedLayer,
              let mask = layer.mask,
              let alphaMask = alphaChannelMask(fromLayerMask: mask, layer: layer),
              alphaMask.selectedBounds(in: document.canvasSize) != nil
        else {
            statusText = L10n.text("imageEditor.status.alphaChannelFromMaskFailed")
            return
        }

        pushUndo()
        let nextIndex = document.alphaChannels.count + 1
        document.alphaChannels.append(
            ImageEditorAlphaChannel(
                name: L10n.format("imageEditor.channel.alphaChannelFromMaskName", nextIndex),
                mask: alphaMask
            )
        )
        appendHistory(L10n.text("imageEditor.history.alphaChannelFromMask"))
        statusText = L10n.text("imageEditor.status.alphaChannelFromMask")
    }

    func renameAlphaChannel(_ id: UUID, to proposedName: String) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusText = L10n.text("imageEditor.status.alphaChannelNameInvalid")
            return
        }
        guard document.alphaChannels[index].name != trimmedName else { return }

        pushUndo()
        document.alphaChannels[index].name = trimmedName
        appendHistory(L10n.text("imageEditor.history.alphaChannelRename"))
        statusText = L10n.text("imageEditor.status.alphaChannelRenamed")
    }

    func duplicateAlphaChannel(_ id: UUID) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }

        var duplicatedChannel = document.alphaChannels[index]
        duplicatedChannel.id = UUID()
        duplicatedChannel.name = uniqueAlphaChannelName(
            L10n.format("imageEditor.channel.alphaChannelCopyName", duplicatedChannel.name)
        )

        pushUndo()
        document.alphaChannels.insert(duplicatedChannel, at: index + 1)
        appendHistory(L10n.text("imageEditor.history.alphaChannelDuplicate"))
        statusText = L10n.format("imageEditor.status.alphaChannelDuplicated", duplicatedChannel.name)
    }

    func updateAlphaChannelFromSelection(_ id: UUID) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        guard let mask = document.selection?.rasterizedMask(canvasSize: document.canvasSize),
              mask.selectedBounds(in: document.canvasSize) != nil
        else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }

        pushUndo()
        document.alphaChannels[index].mask = mask
        appendHistory(L10n.text("imageEditor.history.alphaChannelUpdate"))
        statusText = L10n.format("imageEditor.status.alphaChannelUpdated", document.alphaChannels[index].name)
    }

    func applyAlphaChannelToSelectedLayerMask(_ id: UUID) {
        guard canApplyAlphaChannelToSelectedLayerMask,
              let layerIndex = document.selectedLayerIndex,
              let channel = document.alphaChannels.first(where: { $0.id == id }),
              let mask = layerMask(fromAlphaChannel: channel, layer: document.layers[layerIndex])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[layerIndex].mask = mask
        document.layers[layerIndex].isMaskEnabled = true
        document.layers[layerIndex].isMaskLinked = true
        document.layers[layerIndex].maskDensity = 1
        document.layers[layerIndex].maskFeather = 0
        isEditingLayerMask = true
        appendHistory(L10n.text("imageEditor.history.alphaChannelApplyToMask"))
        statusText = L10n.format("imageEditor.status.alphaChannelApplyToMask", channel.name)
    }

    func loadSelectionFromAlphaChannel(_ id: UUID) {
        guard let channel = document.alphaChannels.first(where: { $0.id == id }),
              let bounds = channel.mask.selectedBounds(in: document.canvasSize)
        else {
            statusText = L10n.text("imageEditor.status.alphaChannelSelectionEmpty")
            return
        }

        let selection = ImageEditorSelection.raster(mask: channel.mask, bounds: bounds)
        applySelectionCandidate(selection, replaceHistoryKey: "imageEditor.history.alphaChannelLoad")
        if document.selection != nil {
            statusText = L10n.format("imageEditor.status.alphaChannelLoaded", channel.name)
        }
    }

    func deleteAlphaChannel(_ id: UUID) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }

        pushUndo()
        document.alphaChannels.remove(at: index)
        appendHistory(L10n.text("imageEditor.history.alphaChannelDelete"))
        statusText = L10n.text("imageEditor.status.alphaChannelDeleted")
    }

    func alphaChannelPreviewImage(_ channel: ImageEditorAlphaChannel) -> NSImage {
        channel.mask.grayscalePreviewImage(targetSize: document.canvasSize)
    }

    private func uniqueAlphaChannelName(_ baseName: String) -> String {
        let existingNames = Set(document.alphaChannels.map(\.name))
        guard existingNames.contains(baseName) else { return baseName }

        var suffix = 2
        while existingNames.contains("\(baseName) \(suffix)") {
            suffix += 1
        }
        return "\(baseName) \(suffix)"
    }

    private func layerMask(fromAlphaChannel channel: ImageEditorAlphaChannel, layer: ImageEditorLayer) -> NSImage? {
        guard let canvasMask = NSImage.selectionMaskImage(channel.mask, inverted: false, targetSize: document.canvasSize) else {
            return nil
        }

        if layer.isGroup {
            return canvasMask
        }

        guard layer.image.size.width > 0,
              layer.image.size.height > 0,
              layer.frame.width > 0,
              layer.frame.height > 0
        else { return nil }

        return NSImage.rendered(size: layer.image.size) { _ in
            canvasMask.draw(
                in: CGRect(origin: .zero, size: layer.image.size),
                from: layer.frame,
                operation: .copy,
                fraction: 1
            )
        }
    }

    private func alphaChannelMask(fromLayerMask mask: NSImage, layer: ImageEditorLayer) -> ImageEditorSelectionMask? {
        let canvasMask: NSImage?
        if layer.isGroup {
            canvasMask = mask.resized(to: document.canvasSize)
        } else {
            canvasMask = NSImage.rendered(size: document.canvasSize) { _ in
                NSColor.clear.setFill()
                CGRect(origin: .zero, size: document.canvasSize).fill()
                mask.draw(
                    in: layer.frame,
                    from: CGRect(origin: .zero, size: mask.size),
                    operation: .copy,
                    fraction: 1
                )
            }
        }
        return canvasMask?.alphaMask(width: max(1, Int(document.canvasSize.width.rounded())), height: max(1, Int(document.canvasSize.height.rounded())))
    }
}

extension NSImage {
    func channelPreview(_ channel: ImageEditorChannelPreview) -> NSImage {
        guard channel != .composite,
              let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return self
        }

        let width = cgImage.width
        let height = cgImage.height
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
        ) else {
            return self
        }

        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let value: UInt8
                switch channel {
                case .composite:
                    value = 0
                case .red:
                    value = pixels[offset]
                case .green:
                    value = pixels[offset + 1]
                case .blue:
                    value = pixels[offset + 2]
                case .alpha:
                    value = pixels[offset + 3]
                }
                pixels[offset] = value
                pixels[offset + 1] = value
                pixels[offset + 2] = value
                pixels[offset + 3] = UInt8.max
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let output = CGImage(
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
        else {
            return self
        }

        return NSImage(cgImage: output, size: size)
    }

    func channelSelection(_ channel: ImageEditorChannelPreview, canvasSize: CGSize) -> ImageEditorSelection? {
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
        ) else {
            return nil
        }

        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let value: UInt8
                switch channel {
                case .composite:
                    value = Self.luminance(red: pixels[offset], green: pixels[offset + 1], blue: pixels[offset + 2])
                case .red:
                    value = pixels[offset]
                case .green:
                    value = pixels[offset + 1]
                case .blue:
                    value = pixels[offset + 2]
                case .alpha:
                    value = pixels[offset + 3]
                }
                alpha[y * width + x] = value
            }
        }

        let mask = ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
        guard let bounds = mask.selectedBounds(in: canvasSize) else { return nil }
        return .raster(mask: mask, bounds: bounds)
    }

    private static func luminance(red: UInt8, green: UInt8, blue: UInt8) -> UInt8 {
        let value = 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)
        return UInt8(max(0, min(255, value.rounded())))
    }
}

extension ImageEditorSelectionMask {
    func grayscalePreviewImage(targetSize: CGSize) -> NSImage {
        guard width > 0, height > 0, alpha.count == width * height else {
            return NSImage(size: targetSize)
        }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let alphaValue = alpha[y * width + x]
                let offset = y * bytesPerRow + x * bytesPerPixel
                pixels[offset] = alphaValue
                pixels[offset + 1] = alphaValue
                pixels[offset + 2] = alphaValue
                pixels[offset + 3] = UInt8.max
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let output = CGImage(
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
        else {
            return NSImage(size: targetSize)
        }

        return NSImage(cgImage: output, size: targetSize)
    }
}

extension NSImage {
    func alphaMask(width: Int, height: Int) -> ImageEditorSelectionMask? {
        guard width > 0,
              height > 0,
              let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

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
                alpha[y * width + x] = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }
}
