//
//  XomoCanvasObject.swift
//  veilpic
//

import AppKit
import Foundation

enum ImageEditorTextHitTesting {
    nonisolated static let viewTolerance: CGFloat = 4

    nonisolated static func canvasTolerance(displayScale: CGFloat) -> CGFloat {
        guard displayScale.isFinite, displayScale > 0 else { return viewTolerance }
        return viewTolerance / displayScale
    }
}

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

enum ImageEditorMoveAutoSelectTarget: String, CaseIterable, Identifiable {
    case group
    case layer

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.option.moveAutoSelectTarget.\(rawValue)")
    }
}

enum ImageEditorObjectBoxSelectionPolicy {
    nonisolated static let activationDistance: CGFloat = 3

    nonisolated static func isActivated(viewTranslation: CGSize) -> Bool {
        hypot(viewTranslation.width, viewTranslation.height) >= activationDistance
    }

    nonisolated static func selectionRect(from start: CGPoint, to end: CGPoint) -> CGRect? {
        guard start.x.isFinite,
              start.y.isFinite,
              end.x.isFinite,
              end.y.isFinite
        else { return nil }
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        guard rect.width > 0 || rect.height > 0 else { return nil }
        return rect
    }
}

enum ImageEditorMoveToolDoubleClickTarget: Equatable {
    case editableText(UUID)
    case layer(UUID)

    var layerID: UUID {
        switch self {
        case let .editableText(layerID), let .layer(layerID):
            layerID
        }
    }
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
        if hasMovableDeepSelectedCanvasLayer(at: point) {
            return .movable
        }
        guard let hit = topmostCanvasContent(at: point) else { return .none }
        return hit.isMovable ? .movable : .blocked
    }

    /// Auto-Select is a toolbox option. Component-library mode always keeps
    /// its object-selection behavior even if the last Move tool session was
    /// locked to the current layer.
    var moveToolAutoSelectsCanvasTarget: Bool {
        selectedLeftSidebarTab == .components || isMoveToolAutoSelectEnabled
    }

    /// Returns stable box-selection targets without changing document state.
    /// Layer scope uses visible leaf bounds, Group scope promotes every hit to
    /// its outermost container, and component mode preserves whole component
    /// instances while still allowing ordinary top-level artwork.
    func moveToolBoxSelectionTargetIDs(in selectionRect: CGRect) -> [UUID] {
        let rect = selectionRect.standardized
        guard rect.width > 0,
              rect.height > 0,
              rect.origin.x.isFinite,
              rect.origin.y.isFinite,
              rect.width.isFinite,
              rect.height.isFinite
        else { return [] }

        let componentObjects = xomoCanvasObjects()
        let componentGroupIDs = Set(componentObjects.map(\.groupID))
        var orderedIDs: [UUID] = []
        var seenIDs: Set<UUID> = []

        func append(_ id: UUID) {
            guard seenIDs.insert(id).inserted else { return }
            orderedIDs.append(id)
        }

        if selectedLeftSidebarTab == .components {
            for object in componentObjects.sorted(by: { $0.frontIndex < $1.frontIndex })
            where rect.intersects(object.frame.standardized) {
                append(object.groupID)
            }
        }

        for layer in document.layers {
            guard !layer.isGroup,
                  !layer.isAdjustment,
                  !layer.isFilter,
                  document.isEffectivelyVisible(layer),
                  layer.frame.standardized.width > 0,
                  layer.frame.standardized.height > 0,
                  rect.intersects(layer.frame.standardized)
            else { continue }

            let ancestors = document.ancestorGroups(for: layer)
            if selectedLeftSidebarTab == .components {
                guard !ancestors.contains(where: { componentGroupIDs.contains($0.id) }) else {
                    continue
                }
                append(layer.id)
                continue
            }

            switch moveToolAutoSelectTarget {
            case .layer:
                append(layer.id)
            case .group:
                append(ancestors.last?.id ?? layer.id)
            }
        }
        return orderedIDs
    }

    /// Applies a Sketch/Figma-style intersection sweep as a selection-only
    /// operation. It intentionally does not create History or Undo entries.
    @discardableResult
    func applyMoveToolBoxSelection(
        in selectionRect: CGRect,
        extendingSelection: Bool
    ) -> Bool {
        let targetIDs = moveToolBoxSelectionTargetIDs(in: selectionRect)
        let previousIDs = document.selectedLayerIDs

        if extendingSelection {
            for id in targetIDs where !document.selectedLayerIDs.contains(id) {
                selectLayer(id, extendingSelection: true)
            }
        } else if let firstID = targetIDs.first {
            selectLayer(firstID)
            for id in targetIDs.dropFirst() where !document.selectedLayerIDs.contains(id) {
                selectLayer(id, extendingSelection: true)
            }
        } else {
            clearLayerSelection()
        }

        guard document.selectedLayerIDs != previousIDs else { return false }
        statusText = document.selectedLayerIDs.isEmpty
            ? L10n.text("imageEditor.status.layerSelectionCleared")
            : L10n.format(
                "imageEditor.status.layerRangeSelected",
                document.selectedLayerIDs.count
            )
        return true
    }

    /// Cursor feedback follows the same target policy as pointer activation.
    /// With Auto-Select disabled, any drawable canvas point can start moving
    /// the current visible selection; a locked selection remains prohibited.
    func moveToolContentHit(at point: CGPoint) -> XomoCanvasContentHit {
        guard !moveToolAutoSelectsCanvasTarget else {
            if selectedLeftSidebarTab == .tools,
               let target = moveToolAutoSelectLayer(at: point) {
                if hasMovableDeepSelectedCanvasLayer(at: point) {
                    return .movable
                }
                return isMoveToolAutoSelectTargetMovable(target) ? .movable : .blocked
            }
            return canvasContentHit(at: point)
        }
        guard point.x.isFinite,
              point.y.isFinite,
              selectedLayerTransformFrame != nil
        else { return .none }
        return canMoveSelectedLayer ? .movable : .blocked
    }

    /// Resolves the object under an idle Option-hover without changing the
    /// current selection. Distance inspection follows the Move tool's
    /// Group/Layer scope, while component-library mode keeps whole components.
    func moveToolDistanceInspectionTargetFrame(at point: CGPoint) -> CGRect? {
        guard point.x.isFinite, point.y.isFinite else { return nil }

        if selectedLeftSidebarTab == .components {
            guard let object = topmostXomoObject(at: point),
                  !document.selectedLayerIDs.contains(object.groupID)
            else { return nil }
            return object.frame.standardized
        }

        guard let leaf = frontmostVisibleCanvasLayer(at: point) else { return nil }
        let target: ImageEditorLayer
        switch moveToolAutoSelectTarget {
        case .layer:
            target = leaf
        case .group:
            target = document.ancestorGroups(for: leaf).last ?? leaf
        }
        guard !document.selectedLayerIDs.contains(target.id),
              !document.ancestorGroups(for: target).contains(where: {
                  document.selectedLayerIDs.contains($0.id)
              })
        else { return nil }

        guard target.isGroup else { return target.frame.standardized }
        return document.layers.lazy
            .filter { layer in
                !layer.isGroup
                    && self.document.isEffectivelyVisible(layer)
                    && self.document.ancestorGroups(for: layer).contains(where: { $0.id == target.id })
            }
            .map { $0.frame.standardized }
            .reduce(nil) { bounds, frame in
                bounds?.union(frame) ?? frame
            }
    }

    func moveToolDistanceInspectionGuides(at point: CGPoint) -> [ImageEditorSpacingGuide] {
        guard let sourceFrame = selectedXomoObjectFrame ?? selectedLayerTransformFrame,
              let targetFrame = ImageEditorObjectDistanceInspectionTargetResolver.frame(
                hoveredObjectFrame: moveToolDistanceInspectionTargetFrame(at: point),
                canvasSize: document.canvasSize
              )
        else { return [] }
        return ImageEditorObjectDistanceMeasurement.guides(
            from: sourceFrame,
            to: targetFrame
        )
    }

    /// Resolves the visible leaf first, then optionally promotes it to the
    /// outermost ordinary/component group. This matches Photoshop's Group
    /// scope and Figma's first-click container selection.
    func moveToolAutoSelectLayer(at point: CGPoint) -> ImageEditorLayer? {
        guard selectedLeftSidebarTab == .tools,
              isMoveToolAutoSelectEnabled,
              let leaf = frontmostVisibleCanvasLayer(at: point)
        else { return nil }
        switch moveToolAutoSelectTarget {
        case .layer:
            return leaf
        case .group:
            return document.ancestorGroups(for: leaf).last ?? leaf
        }
    }

    private func isMoveToolAutoSelectTargetMovable(_ target: ImageEditorLayer) -> Bool {
        guard target.isGroup else {
            return !document.isEffectivelyPositionLocked(target)
        }
        let transformableDescendants = document.layers.filter { layer in
            !layer.isGroup
                && !layer.isAdjustment
                && !layer.isFilter
                && document.ancestorGroups(for: layer).contains { $0.id == target.id }
        }
        return !transformableDescendants.isEmpty
            && transformableDescendants.allSatisfy {
                !document.isEffectivelyPositionLocked($0)
            }
    }

    private func frontmostVisibleCanvasLayer(at point: CGPoint) -> ImageEditorLayer? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        return document.layers.reversed().first { layer in
            !layer.isGroup
                && document.isEffectivelyVisible(layer)
                && layerContainsVisibleContent(layer, at: point)
        }
    }

    /// The AppKit fast path asks this at mouse-down before it owns the full
    /// pointer sequence. Auto-Select off intentionally accepts blank canvas
    /// so the already-selected layer can be dragged without retargeting.
    func canBeginCanvasObjectMove(at point: CGPoint) -> Bool {
        if !moveToolAutoSelectsCanvasTarget {
            return moveToolContentHit(at: point) == .movable
        }
        if hasMovableDeepSelectedCanvasLayer(at: point) {
            return true
        }
        return hasXomoObject(at: point) && moveToolContentHit(at: point) == .movable
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
        guard let object = topmostXomoObject(at: point) else { return false }

        selectLayer(object.groupID, extendingSelection: extendingSelection)
        statusText = extendingSelection
            ? L10n.format("imageEditor.status.layerRangeSelected", document.selectedLayerIDs.count)
            : L10n.format("xomo.object.status.selected", object.kind.title)
        return true
    }

    /// Resolves the frontmost component again when a drag begins. Merely
    /// landing inside the old selection bounds is insufficient: another
    /// component or an ordinary layer may now be in front. Existing
    /// multi-selection is preserved when the resolved object is already part
    /// of it, matching Sketch/Figma group-drag behavior.
    func prepareXomoObjectMove(at point: CGPoint) -> Bool {
        guard let object = topmostXomoObject(at: point) else { return false }
        if document.selectedLayerIDs.contains(object.groupID), selectedXomoObjectFrame != nil {
            return true
        }
        selectLayer(object.groupID)
        statusText = L10n.format("xomo.object.status.selected", object.kind.title)
        return true
    }

    /// A child reached through direct selection remains the drag target in
    /// tools mode. The selected layer must own the frontmost visible pixel;
    /// this prevents a stale deep selection from moving through an occluder.
    func hasMovableDeepSelectedCanvasLayer(at point: CGPoint) -> Bool {
        guard selectedLeftSidebarTab == .tools,
              document.selectedLayerIDs.count == 1,
              let selectedLayer = document.selectedLayer,
              !selectedLayer.isGroup,
              selectedLayer.groupID != nil,
              canMoveSelectedLayer,
              document.isEffectivelyVisible(selectedLayer),
              layerContainsVisibleContent(selectedLayer, at: point)
        else { return false }

        return document.layers.reversed().first { layer in
            !layer.isGroup
                && document.isEffectivelyVisible(layer)
                && layerContainsVisibleContent(layer, at: point)
        }?.id == selectedLayer.id
    }

    /// Native canvas dragging shares one activation path for component
    /// objects and directly selected children. Components mode always falls
    /// through to whole-object preparation.
    func prepareCanvasObjectMove(at point: CGPoint) -> Bool {
        if !moveToolAutoSelectsCanvasTarget {
            return moveToolContentHit(at: point) == .movable
        }
        if selectedLeftSidebarTab == .tools {
            if hasMovableDeepSelectedCanvasLayer(at: point) {
                return true
            }
            if let target = moveToolAutoSelectLayer(at: point),
               document.selectedLayerIDs.contains(target.id),
               selectedLayerTransformFrame != nil {
                return true
            }
            return selectMoveToolAutoSelectTarget(at: point)
        }
        return prepareXomoObjectMove(at: point)
    }

    /// Option-drag preserves an already deep-selected child in tools mode.
    /// Otherwise the conventional selection path chooses the component object
    /// or ordinary frontmost layer before the duplication transaction starts.
    func prepareCanvasCloneMove(at point: CGPoint) -> Bool {
        if !moveToolAutoSelectsCanvasTarget {
            return moveToolContentHit(at: point) == .movable
        }
        return hasMovableDeepSelectedCanvasLayer(at: point)
            || selectMovableCanvasTarget(at: point)
    }

    /// SwiftUI owns ordinary layers and the macOS 13 fallback. Keep its
    /// selection rule aligned with the native component/deep-selection path.
    func prepareCanvasFallbackMove(at point: CGPoint) -> Bool {
        if !moveToolAutoSelectsCanvasTarget {
            return moveToolContentHit(at: point) == .movable
        }
        return selectMovableCanvasTarget(at: point)
    }

    /// Shared move-target selection for both the transparent object hit target
    /// and the canvas gesture fallback used by macOS 13. Component instances
    /// must win before ordinary layers so their children never steal a drag.
    func selectMovableCanvasTarget(at point: CGPoint, extendingSelection: Bool = false) -> Bool {
        if selectedLeftSidebarTab == .tools {
            return selectMoveToolAutoSelectTarget(
                at: point,
                extendingSelection: extendingSelection
            )
        }
        return selectXomoObject(at: point, extendingSelection: extendingSelection)
            || selectVisibleLayer(at: point, extendingSelection: extendingSelection)
    }

    @discardableResult
    func selectMoveToolAutoSelectTarget(
        at point: CGPoint,
        extendingSelection: Bool = false
    ) -> Bool {
        guard let target = moveToolAutoSelectLayer(at: point) else { return false }
        selectLayer(target.id, extendingSelection: extendingSelection)
        statusText = L10n.format(
            "imageEditor.status.layerRangeSelected",
            document.selectedLayerIDs.count
        )
        return true
    }

    /// Returns whether a component object owns the point without changing
    /// selection state. Canvas gesture arbitration uses this fast query to
    /// keep component drags out of the ordinary move fallback.
    func hasXomoObject(at point: CGPoint) -> Bool {
        topmostXomoObject(at: point) != nil
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
    func selectEditableTextLayer(
        at point: CGPoint,
        excluding excludedLayerID: UUID? = nil,
        hitTolerance: CGFloat = ImageEditorTextHitTesting.viewTolerance
    ) -> Bool {
        guard let layer = editableTextLayer(
            at: point,
            excluding: excludedLayerID,
            hitTolerance: hitTolerance
        ) else { return false }

        selectLayer(layer.id)
        return true
    }

    /// Resolves one foreground target for a plain Move-tool double-click.
    /// Text keeps a small frame tolerance for whitespace and edge editing,
    /// while ordinary layers require a visible pixel and therefore prevent
    /// the click from tunnelling through an opaque cover to text underneath.
    func moveToolDoubleClickTarget(
        at point: CGPoint,
        hitTolerance: CGFloat = ImageEditorTextHitTesting.viewTolerance
    ) -> ImageEditorMoveToolDoubleClickTarget? {
        guard point.x.isFinite, point.y.isFinite else { return nil }

        let tolerance = max(0, hitTolerance)
        for layer in document.layers.reversed() {
            guard !layer.isGroup, document.isEffectivelyVisible(layer) else { continue }

            let isHit = if layer.isText {
                layer.frame.standardized
                    .insetBy(dx: -tolerance, dy: -tolerance)
                    .contains(point)
            } else {
                layerContainsVisibleContent(layer, at: point)
            }
            guard isHit else { continue }

            if layer.isText, !document.isEffectivelyPixelsLocked(layer) {
                return .editableText(layer.id)
            }
            return .layer(layer.id)
        }
        return nil
    }

    @discardableResult
    func selectMoveToolDoubleClickTarget(
        at point: CGPoint,
        hitTolerance: CGFloat = ImageEditorTextHitTesting.viewTolerance
    ) -> ImageEditorMoveToolDoubleClickTarget? {
        guard let target = moveToolDoubleClickTarget(
            at: point,
            hitTolerance: hitTolerance
        ) else { return nil }

        selectLayer(target.layerID)
        statusText = L10n.format(
            "imageEditor.status.layerRangeSelected",
            document.selectedLayerIDs.count
        )
        return target
    }

    private func editableTextLayer(
        at point: CGPoint,
        excluding excludedLayerID: UUID? = nil,
        hitTolerance: CGFloat
    ) -> ImageEditorLayer? {
        let tolerance = max(0, hitTolerance)
        return document.layers.reversed().first { layer in
            layer.isText
                && layer.id != excludedLayerID
                && document.isEffectivelyVisible(layer)
                && !document.isEffectivelyPixelsLocked(layer)
                && layer.frame.standardized.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
    }

    func deleteSelectedXomoObjectIfNeeded() -> Bool {
        guard !hasActiveLayerMoveTransaction,
              let selected = document.selectedLayer,
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

    /// Sketch/Figma-style Escape navigation after direct selection drills
    /// into a group. Active pointer transactions are cancelled by the view
    /// before this fallback runs, so one Escape only changes selection depth.
    func exitDeepCanvasSelectionIfNeeded() -> Bool {
        guard selectedLeftSidebarTab == .tools,
              document.selectedLayerIDs.count == 1,
              let selectedLayer = document.selectedLayer,
              document.group(for: selectedLayer) != nil
        else { return false }

        selectParentGroup()
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

    private func topmostXomoObject(at point: CGPoint) -> XomoCanvasObject? {
        xomoCanvasObjects()
            .sorted(by: { $0.frontIndex > $1.frontIndex })
            .first { object in
                object.frame.contains(point) && !isXomoObjectOccluded(object, at: point)
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
