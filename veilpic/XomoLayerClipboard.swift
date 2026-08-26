//
//  XomoLayerClipboard.swift
//  veilpic
//
//  Created by Codex on 2026/8/26.
//

import AppKit
import Foundation

struct XomoRestoredLayerClipboardArchive {
    var layers: [ImageEditorLayer]
    var selectedRootIDs: Set<UUID>
    var primaryRootID: UUID?
}

/// Xomo's private, editable clipboard flavor. A public PNG is written beside
/// this payload so copying continues to interoperate with other applications.
@MainActor
enum XomoLayerClipboardArchive {
    static let pasteboardType = NSPasteboard.PasteboardType("im.some.xomo.layers.v1")
    static let normalPasteOffset = CGPoint(x: 10, y: 10)

    private static let formatVersion = 1
    private static let maximumLayerCount = 4_096
    private static let maximumPayloadSize = 128 * 1_024 * 1_024

    private struct Archive: Codable {
        var version: Int
        var layers: [ImageEditorProjectLayer]
        var rootIDs: [UUID]
        var primaryRootID: UUID?
    }

    static func containsSupportedData(in pasteboard: NSPasteboard) -> Bool {
        guard let data = pasteboard.data(forType: pasteboardType) else { return false }
        return !data.isEmpty && data.count <= maximumPayloadSize
    }

    static func data(
        layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        primarySelectionID: UUID?
    ) -> Data? {
        let rootIDSet = ImageEditorLayerHierarchyDuplication.duplicableRootIDs(
            in: layers,
            selectedIDs: selectedIDs
        )
        guard !rootIDSet.isEmpty else { return nil }

        let includedIDs = includedLayerIDs(rootIDs: rootIDSet, layers: layers)
        guard !includedIDs.isEmpty, includedIDs.count <= maximumLayerCount else { return nil }
        let sourceLayers = layers.filter { includedIDs.contains($0.id) }
        let sourceLayerByID = Dictionary(uniqueKeysWithValues: sourceLayers.map { ($0.id, $0) })

        let projectLayers: [ImageEditorProjectLayer]
        do {
            projectLayers = try sourceLayers.enumerated().map { index, layer in
                var projectLayer = try ImageEditorProjectLayer(layer: layer)
                if let parentID = layer.groupID,
                   includedIDs.contains(parentID),
                   sourceLayerByID[parentID]?.isGroup == true {
                    projectLayer.groupID = parentID
                } else {
                    projectLayer.groupID = nil
                }
                projectLayer.linkedLayerIDs = layer.linkedLayerIDs
                    .intersection(includedIDs)
                    .subtracting([layer.id])
                if var component = projectLayer.xomoComponentInstance {
                    component.masterID = component.masterID.flatMap {
                        includedIDs.contains($0) ? $0 : nil
                    }
                    projectLayer.xomoComponentInstance = component
                }
                if layer.isClippingMask,
                   clippingBaseID(for: layer, at: index, in: sourceLayers) == nil {
                    projectLayer.isClippingMask = false
                }
                return projectLayer
            }
        } catch {
            return nil
        }

        let orderedRootIDs = layers.compactMap { rootIDSet.contains($0.id) ? $0.id : nil }
        let primaryRootID = rootID(
            containing: primarySelectionID,
            rootIDs: rootIDSet,
            layersByID: Dictionary(uniqueKeysWithValues: layers.map { ($0.id, $0) })
        ) ?? orderedRootIDs.last
        let archive = Archive(
            version: formatVersion,
            layers: projectLayers,
            rootIDs: orderedRootIDs,
            primaryRootID: primaryRootID
        )
        guard let data = try? JSONEncoder().encode(archive),
              !data.isEmpty,
              data.count <= maximumPayloadSize
        else { return nil }
        return data
    }

    static func restoredCopy(
        from pasteboard: NSPasteboard,
        offset: CGPoint
    ) -> XomoRestoredLayerClipboardArchive? {
        guard offset.x.isFinite,
              offset.y.isFinite,
              let data = pasteboard.data(forType: pasteboardType),
              !data.isEmpty,
              data.count <= maximumPayloadSize,
              let archive = try? JSONDecoder().decode(Archive.self, from: data),
              archive.version == formatVersion,
              !archive.layers.isEmpty,
              archive.layers.count <= maximumLayerCount,
              archive.rootIDs.isEmpty == false
        else { return nil }

        let sourceIDs = archive.layers.map(\.id)
        let sourceIDSet = Set(sourceIDs)
        guard sourceIDSet.count == sourceIDs.count,
              Set(archive.rootIDs).count == archive.rootIDs.count,
              Set(archive.rootIDs).isSubset(of: sourceIDSet),
              archive.primaryRootID.map(sourceIDSet.contains) ?? true
        else { return nil }

        let restoredSourceLayers: [ImageEditorLayer]
        do {
            restoredSourceLayers = try archive.layers.map { try $0.restoredLayer() }
        } catch {
            return nil
        }
        guard restoredSourceLayers.allSatisfy({ layer in
            layer.frame.minX.isFinite
                && layer.frame.minY.isFinite
                && layer.frame.width.isFinite
                && layer.frame.height.isFinite
                && layer.frame.width > 0
                && layer.frame.height > 0
        }) else { return nil }

        let sourceLayerByID = Dictionary(
            uniqueKeysWithValues: restoredSourceLayers.map { ($0.id, $0) }
        )
        let newIDBySourceID = Dictionary(
            uniqueKeysWithValues: sourceIDs.map { ($0, UUID()) }
        )
        var restoredLayers = restoredSourceLayers.enumerated().map { index, source -> ImageEditorLayer in
            var layer = source
            layer.id = newIDBySourceID[source.id] ?? UUID()
            layer.frame = source.frame.offsetBy(dx: offset.x, dy: offset.y)
            if let parentID = source.groupID,
               sourceLayerByID[parentID]?.isGroup == true {
                layer.groupID = newIDBySourceID[parentID]
            } else {
                layer.groupID = nil
            }
            layer.linkedLayerIDs = Set(source.linkedLayerIDs.compactMap {
                newIDBySourceID[$0]
            }).subtracting([layer.id])
            if var component = layer.xomoComponentInstance {
                component.masterID = component.masterID.flatMap { newIDBySourceID[$0] }
                layer.xomoComponentInstance = component
            }
            if source.isClippingMask,
               clippingBaseID(for: source, at: index, in: restoredSourceLayers) == nil {
                layer.isClippingMask = false
            }
            return layer
        }

        guard restoredLayers.allSatisfy({ layer in
            layer.frame.minX.isFinite
                && layer.frame.minY.isFinite
                && layer.frame.width.isFinite
                && layer.frame.height.isFinite
        }) else { return nil }

        // Ensure links are symmetric inside the archive before it is appended
        // to a document. External references were deliberately removed above.
        let restoredIndexByID = Dictionary(
            uniqueKeysWithValues: restoredLayers.indices.map { (restoredLayers[$0].id, $0) }
        )
        for index in restoredLayers.indices {
            for linkedID in restoredLayers[index].linkedLayerIDs {
                guard let linkedIndex = restoredIndexByID[linkedID] else { continue }
                restoredLayers[linkedIndex].linkedLayerIDs.insert(restoredLayers[index].id)
            }
        }

        let selectedRootIDs = Set(archive.rootIDs.compactMap { newIDBySourceID[$0] })
        guard !selectedRootIDs.isEmpty else { return nil }
        return XomoRestoredLayerClipboardArchive(
            layers: restoredLayers,
            selectedRootIDs: selectedRootIDs,
            primaryRootID: archive.primaryRootID.flatMap { newIDBySourceID[$0] }
                ?? restoredLayers.reversed().first(where: { selectedRootIDs.contains($0.id) })?.id
        )
    }

    private static func includedLayerIDs(
        rootIDs: Set<UUID>,
        layers: [ImageEditorLayer]
    ) -> Set<UUID> {
        var includedIDs = rootIDs
        var pendingGroupIDs = layers.compactMap { layer in
            rootIDs.contains(layer.id) && layer.isGroup ? layer.id : nil
        }
        while let groupID = pendingGroupIDs.popLast() {
            for layer in layers where layer.groupID == groupID && !includedIDs.contains(layer.id) {
                includedIDs.insert(layer.id)
                if layer.isGroup {
                    pendingGroupIDs.append(layer.id)
                }
            }
        }
        return includedIDs
    }

    private static func rootID(
        containing selectedID: UUID?,
        rootIDs: Set<UUID>,
        layersByID: [UUID: ImageEditorLayer]
    ) -> UUID? {
        guard var candidateID = selectedID else { return nil }
        var visitedIDs = Set<UUID>()
        while visitedIDs.insert(candidateID).inserted {
            if rootIDs.contains(candidateID) {
                return candidateID
            }
            guard let parentID = layersByID[candidateID]?.groupID else { return nil }
            candidateID = parentID
        }
        return nil
    }

    private static func clippingBaseID(
        for layer: ImageEditorLayer,
        at index: Int,
        in layers: [ImageEditorLayer]
    ) -> UUID? {
        guard layer.isClippingMask,
              index > 0,
              layers.indices.contains(index)
        else { return nil }
        return layers[..<index].reversed().first { candidate in
            !candidate.isGroup
                && !candidate.isAdjustment
                && !candidate.isFilter
                && !candidate.isClippingMask
                && candidate.groupID == layer.groupID
        }?.id
    }
}
