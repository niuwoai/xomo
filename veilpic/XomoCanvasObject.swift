//
//  XomoCanvasObject.swift
//  veilpic
//

import AppKit
import Foundation

private struct XomoCanvasObject {
    let groupID: UUID
    let kind: XomoComponentKind
    let frame: CGRect
    let frontIndex: Int
}

@MainActor
extension ImageEditorViewModel {
    var hasSelectedXomoObject: Bool {
        selectedXomoObjectKind != nil
    }

    var selectedXomoObjectKind: XomoComponentKind? {
        guard let selectedLayer = document.selectedLayer,
              selectedLayer.isGroup
        else { return nil }
        return selectedLayer.xomoComponentInstance?.kind
    }

    var selectedXomoObjectFrame: CGRect? {
        guard hasSelectedXomoObject,
              let selectedGroupID = document.selectedLayerID
        else { return nil }
        return document.layers.lazy
            .filter { layer in
                layer.groupID == selectedGroupID && self.document.isEffectivelyVisible(layer)
            }
            .map { $0.frame.standardized }
            .reduce(nil) { bounds, frame in
                bounds?.union(frame) ?? frame
            }
    }

    func selectXomoObject(at point: CGPoint) -> Bool {
        guard let object = xomoCanvasObjects()
            .sorted(by: { $0.frontIndex > $1.frontIndex })
            .first(where: { object in
                object.frame.contains(point) && !isXomoObjectOccluded(object, at: point)
            })
        else { return false }

        selectLayer(object.groupID)
        statusText = L10n.format("xomo.object.status.selected", object.kind.title)
        return true
    }

    /// 文字工具优先命中最上方可见文字层。组件中的文字也是普通文字层，
    /// 因而可以从组件组自动切换到具体文字层并直接编辑。
    func selectEditableTextLayer(at point: CGPoint, excluding excludedLayerID: UUID? = nil) -> Bool {
        guard let layer = document.layers.reversed().first(where: { layer in
            layer.isText
                && layer.id != excludedLayerID
                && document.isEffectivelyVisible(layer)
                && !document.isEffectivelyPixelsLocked(layer)
                && layer.frame.standardized.insetBy(dx: -4, dy: -4).contains(point)
        }) else { return false }

        selectLayer(layer.id)
        return true
    }

    func deleteSelectedXomoObjectIfNeeded() -> Bool {
        guard let selected = document.selectedLayer,
              selected.isGroup,
              let kind = selected.xomoComponentInstance?.kind,
              canDeleteLayer
        else { return false }

        deleteSelectedLayer()
        statusText = L10n.format("xomo.object.status.deleted", kind.title)
        return true
    }

    private func xomoCanvasObjects() -> [XomoCanvasObject] {
        let groups = document.layers.enumerated().reduce(into: [UUID: (kind: XomoComponentKind, index: Int)]()) { result, item in
            let (index, layer) = item
            guard layer.isGroup,
                  let instance = layer.xomoComponentInstance,
                  document.isEffectivelyVisible(layer)
            else { return }
            result[layer.id] = (instance.kind, index)
        }
        var boundsByGroupID: [UUID: CGRect] = [:]
        var frontIndexByGroupID: [UUID: Int] = [:]

        for (index, layer) in document.layers.enumerated() {
            guard let groupID = layer.groupID,
                  groups[groupID] != nil,
                  document.isEffectivelyVisible(layer)
            else { continue }
            let frame = layer.frame.standardized
            boundsByGroupID[groupID] = boundsByGroupID[groupID]?.union(frame) ?? frame
            frontIndexByGroupID[groupID] = max(frontIndexByGroupID[groupID] ?? index, index)
        }

        return groups.compactMap { groupID, group in
            guard let frame = boundsByGroupID[groupID] else { return nil }
            return XomoCanvasObject(
                groupID: groupID,
                kind: group.kind,
                frame: frame,
                frontIndex: max(group.index, frontIndexByGroupID[groupID] ?? group.index)
            )
        }
    }

    private func isXomoObjectOccluded(_ object: XomoCanvasObject, at point: CGPoint) -> Bool {
        guard object.frontIndex < document.layers.count - 1 else { return false }
        return document.layers[(object.frontIndex + 1)...].contains { layer in
            guard layer.groupID != object.groupID,
                  !layer.isGroup,
                  document.isEffectivelyVisible(layer),
                  layerContainsVisibleContent(layer, at: point)
            else { return false }
            return true
        }
    }

    /// A transparent editing layer still has a canvas-sized frame, but it does
    /// not visually cover an object underneath. Hit testing the rendered alpha
    /// keeps empty layers and fully masked pixels from stealing component clicks.
    private func layerContainsVisibleContent(_ layer: ImageEditorLayer, at point: CGPoint) -> Bool {
        guard !layer.isAdjustment,
              !layer.isFilter,
              layer.opacity > 0.001,
              layer.fillOpacity > 0.001
        else { return false }

        let frame = layer.frame.standardized
        let visibleImage = layer.visibleImage
        guard frame.width > 0.1,
              frame.height > 0.1,
              frame.contains(point),
              visibleImage.size.width > 0,
              visibleImage.size.height > 0
        else { return false }

        let localPoint = CGPoint(
            x: (point.x - frame.minX) / frame.width * visibleImage.size.width,
            y: (point.y - frame.minY) / frame.height * visibleImage.size.height
        )
        return visibleImage.hasVisiblePixel(at: localPoint)
    }
}

@MainActor
private final class XomoVisiblePixelProbe: NSObject {
    let width: Int
    let height: Int
    let alpha: [UInt8]

    init?(cgImage: CGImage) {
        guard cgImage.width > 0, cgImage.height > 0 else { return nil }
        let bytesPerRow = cgImage.width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * cgImage.height)
        guard let context = CGContext(
            data: &pixels,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        width = cgImage.width
        height = cgImage.height
        alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
    }
}

@MainActor
private enum XomoVisiblePixelProbeCache {
    static let cache: NSCache<NSImage, XomoVisiblePixelProbe> = {
        let cache = NSCache<NSImage, XomoVisiblePixelProbe>()
        cache.countLimit = 48
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    static func probe(for image: NSImage, cgImage: CGImage) -> XomoVisiblePixelProbe? {
        if let cached = cache.object(forKey: image) {
            return cached
        }
        guard let probe = XomoVisiblePixelProbe(cgImage: cgImage) else {
            return nil
        }
        cache.setObject(probe, forKey: image, cost: probe.alpha.count)
        return probe
    }
}

@MainActor
private extension NSImage {
    func hasVisiblePixel(at point: CGPoint, alphaThreshold: UInt8 = 8) -> Bool {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil),
              cgImage.width > 0,
              cgImage.height > 0,
              size.width > 0,
              size.height > 0
        else { return false }

        guard let probe = XomoVisiblePixelProbeCache.probe(for: self, cgImage: cgImage) else {
            return false
        }

        let width = probe.width
        let height = probe.height
        let x = min(max(Int((point.x / size.width * CGFloat(width)).rounded(.down)), 0), width - 1)
        let y = min(max(Int((point.y / size.height * CGFloat(height)).rounded(.down)), 0), height - 1)
        return probe.alpha[y * width + x] > alphaThreshold
    }
}
