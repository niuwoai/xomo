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

enum XomoCanvasContentHit: Equatable {
    case none
    case movable
    case blocked

    var isMovable: Bool { self == .movable }
    var isBlocked: Bool { self == .blocked }
}

@MainActor
extension ImageEditorViewModel {
    var hasSelectedXomoObject: Bool {
        selectedXomoObjectKind != nil && selectedXomoObjectFrame != nil
    }

    var selectedXomoObjectKind: XomoComponentKind? {
        guard let selectedLayer = document.selectedLayer,
              selectedLayer.isGroup
        else { return nil }
        return selectedLayer.xomoComponentInstance?.kind
    }

    var selectedXomoObjectFrame: CGRect? {
        guard document.selectedLayerID != nil,
              !document.selectedLayerIDs.isEmpty,
              document.selectedLayerIDs.allSatisfy({ selectedID in
                  document.layers.contains { layer in
                      layer.id == selectedID && layer.isGroup && layer.xomoComponentInstance != nil
                  }
              })
        else { return nil }
        let selectedGroupIDs = document.selectedLayerIDs
        return document.layers.lazy
            .filter { layer in
                guard let groupID = layer.groupID else { return false }
                return selectedGroupIDs.contains(groupID)
                    && self.document.isEffectivelyVisible(layer)
            }
            .map { $0.frame.standardized }
            .reduce(nil) { bounds, frame in
                bounds?.union(frame) ?? frame
            }
    }

    /// Contextual hit testing for cursor feedback. Transparent pixels and
    /// hidden layers do not claim the move cursor; the move gesture still
    /// performs its stricter selection check before committing.
    func hasMovableCanvasContent(at point: CGPoint) -> Bool {
        canvasContentHit(at: point).isMovable
    }

    /// Distinguishes blocked visible content from empty canvas space for the
    /// move-tool cursor. A locked or occluded object should not look like an
    /// invitation to pan the canvas with an open hand.
    func hasBlockedCanvasContent(at point: CGPoint) -> Bool {
        canvasContentHit(at: point).isBlocked
    }

    /// Resolves the hover target once so the direct cursor path and the
    /// CursorRect fallback cannot disagree or scan the layer stack twice for
    /// one mouse-move event.
    func canvasContentHit(at point: CGPoint) -> XomoCanvasContentHit {
        guard let hit = topmostCanvasContent(at: point) else { return .none }
        return hit.isMovable ? .movable : .blocked
    }

    /// Returns only the frontmost visible pixel at a canvas point. Looking at
    /// every layer would let an unlocked layer underneath a locked cover claim
    /// the move cursor, even though a click can only reach the locked cover.
    private func topmostCanvasContent(at point: CGPoint) -> (isMovable: Bool, isBlocked: Bool)? {
        guard point.x.isFinite, point.y.isFinite else { return nil }

        let componentGroupIDs: Set<UUID> = Set(
            document.layers.compactMap { layer in
                guard layer.isGroup, layer.xomoComponentInstance != nil else { return nil }
                return layer.id
            }
        )
        let objectsByGroupID: [UUID: XomoCanvasObject] = Dictionary(
            uniqueKeysWithValues: xomoCanvasObjects().map { ($0.groupID, $0) }
        )

        for layer in document.layers.reversed() {
            guard !layer.isGroup,
                  document.isEffectivelyVisible(layer),
                  layerContainsVisibleContent(layer, at: point)
            else { continue }

            if let groupID = layer.groupID,
               componentGroupIDs.contains(groupID),
               let object = objectsByGroupID[groupID],
               !isXomoObjectOccluded(object, at: point),
               let group = document.layers.first(where: { $0.id == groupID }) {
                let children = document.layers.filter { $0.groupID == groupID && !$0.isGroup }
                let isMovable = !document.isEffectivelyPositionLocked(group)
                    && !children.isEmpty
                    && children.allSatisfy { !document.isEffectivelyPositionLocked($0) }
                return (isMovable, !isMovable)
            }

            let isMovable = !document.isEffectivelyPositionLocked(layer)
            return (isMovable, !isMovable)
        }
        return nil
    }

    func selectXomoObject(at point: CGPoint, extendingSelection: Bool = false) -> Bool {
        guard let object = xomoCanvasObjects()
            .sorted(by: { $0.frontIndex > $1.frontIndex })
            .first(where: { object in
                object.frame.contains(point) && !isXomoObjectOccluded(object, at: point)
            })
        else { return false }

        selectLayer(object.groupID, extendingSelection: extendingSelection)
        statusText = extendingSelection
            ? L10n.format("imageEditor.status.layerRangeSelected", document.selectedLayerIDs.count)
            : L10n.format("xomo.object.status.selected", object.kind.title)
        return true
    }

    /// Returns whether a component object owns the point without changing
    /// selection state. Canvas gesture arbitration uses this fast query to
    /// keep component drags out of the ordinary move fallback.
    func hasXomoObject(at point: CGPoint) -> Bool {
        xomoCanvasObjects().contains { object in
            object.frame.contains(point) && !isXomoObjectOccluded(object, at: point)
        }
    }

    /// Move-tool hit testing for ordinary Photoshop-style layers. Component
    /// children are intentionally skipped here because their parent object
    /// must remain the selection target; the component path above already
    /// performs the same topmost/occlusion check for them.
    func selectVisibleLayer(at point: CGPoint, extendingSelection: Bool = false) -> Bool {
        let componentGroupIDs: Set<UUID> = Set(
            document.layers.compactMap { layer in
                guard layer.isGroup, layer.xomoComponentInstance != nil else { return nil }
                return layer.id
            }
        )

        for layer in document.layers.reversed() {
            guard !layer.isGroup,
                  layer.groupID.map({ !componentGroupIDs.contains($0) }) ?? true,
                  document.isEffectivelyVisible(layer),
                  layerContainsVisibleContent(layer, at: point)
            else { continue }

            selectLayer(layer.id, extendingSelection: extendingSelection)
            statusText = L10n.format(
                "imageEditor.status.layerRangeSelected",
                document.selectedLayerIDs.count
            )
            return true
        }
        return false
    }

    /// Sketch/Figma-style deep selection for Command-click. Unlike ordinary
    /// move-tool hit testing this intentionally allows a component child to
    /// become the selected layer, while still requiring an actually visible
    /// pixel so transparent children do not steal the click.
    func selectDeepestVisibleLayer(at point: CGPoint, extendingSelection: Bool = false) -> Bool {
        for layer in document.layers.reversed() {
            guard !layer.isGroup,
                  document.isEffectivelyVisible(layer),
                  layerContainsVisibleContent(layer, at: point)
            else { continue }

            selectLayer(layer.id, extendingSelection: extendingSelection)
            statusText = L10n.format(
                "imageEditor.status.layerRangeSelected",
                document.selectedLayerIDs.count
            )
            return true
        }
        return false
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

    /// Escape follows Sketch/Figma object semantics in the component library:
    /// leave the selected object without changing pixels or creating history.
    func clearSelectedXomoObjectIfNeeded() -> Bool {
        guard selectedLeftSidebarTab == .components, hasSelectedXomoObject else { return false }
        clearLayerSelection()
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
