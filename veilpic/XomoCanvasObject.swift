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
        guard let selectedLayer = document.selectedLayer else { return false }
        return selectedLayer.isGroup && selectedLayer.xomoComponentInstance != nil
    }

    var selectedXomoObjectFrame: CGRect? {
        guard hasSelectedXomoObject,
              let selectedGroupID = document.selectedLayerID
        else { return nil }
        return xomoCanvasObjects().first { $0.groupID == selectedGroupID }?.frame
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
        document.layers.enumerated().compactMap { groupIndex, group in
            guard group.isGroup,
                  let instance = group.xomoComponentInstance,
                  document.isEffectivelyVisible(group)
            else { return nil }

            let children = document.layers.enumerated().filter { _, layer in
                layer.groupID == group.id && document.isEffectivelyVisible(layer)
            }
            guard let frame = children
                .map({ $0.element.frame.standardized })
                .reduce(nil, { partial, frame in partial?.union(frame) ?? frame })
            else { return nil }

            let frontIndex = max(groupIndex, children.map(\.offset).max() ?? groupIndex)
            return XomoCanvasObject(
                groupID: group.id,
                kind: instance.kind,
                frame: frame,
                frontIndex: frontIndex
            )
        }
    }

    private func isXomoObjectOccluded(_ object: XomoCanvasObject, at point: CGPoint) -> Bool {
        guard object.frontIndex < document.layers.count - 1 else { return false }
        return document.layers[(object.frontIndex + 1)...].contains { layer in
            guard layer.groupID != object.groupID,
                  !layer.isGroup,
                  document.isEffectivelyVisible(layer)
            else { return false }
            return layer.frame.standardized.contains(point)
        }
    }
}
