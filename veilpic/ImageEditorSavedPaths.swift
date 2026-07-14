//
//  ImageEditorSavedPaths.swift
//  veilpic
//
//  Created by Codex on 2026/7/14.
//

import AppKit
import Foundation

struct ImageEditorSavedPath: Identifiable, Equatable, Codable {
    static let maximumCount = 100
    static let maximumNameLength = 80

    var id = UUID()
    var name: String
    var subpaths: [[ImageEditorPathAnchor]]
    var isClosed: Bool
    var isVisible = false

    var anchorCount: Int {
        subpaths.reduce(0) { $0 + $1.count }
    }

    func normalized(canvasSize: CGSize) -> ImageEditorSavedPath? {
        let normalizedSubpaths = subpaths.compactMap { anchors -> [ImageEditorPathAnchor]? in
            let normalized = anchors.map { $0.normalized(size: canvasSize) }
            let minimumAnchorCount = isClosed ? 3 : 2
            return normalized.count >= minimumAnchorCount ? normalized : nil
        }
        guard !normalizedSubpaths.isEmpty else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        return ImageEditorSavedPath(
            id: id,
            name: String(trimmedName.prefix(Self.maximumNameLength)),
            subpaths: normalizedSubpaths,
            isClosed: isClosed,
            isVisible: isVisible
        )
    }
}

extension ImageEditorSavedPath {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case subpaths
        case isClosed
        case isVisible
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        subpaths = try container.decode([[ImageEditorPathAnchor]].self, forKey: .subpaths)
        isClosed = try container.decode(Bool.self, forKey: .isClosed)
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(subpaths, forKey: .subpaths)
        try container.encode(isClosed, forKey: .isClosed)
        try container.encode(isVisible, forKey: .isVisible)
    }
}

struct ImageEditorSavedPathAnchorOverlayItem: Equatable {
    var subpathIndex: Int
    var anchorIndex: Int
    var point: CGPoint
    var inControl: CGPoint?
    var outControl: CGPoint?
}

@MainActor
extension ImageEditorViewModel {
    var selectedSavedPath: ImageEditorSavedPath? {
        guard let id = document.selectedSavedPathID else { return nil }
        return document.savedPaths.first { $0.id == id }
    }

    var savedPathCanvasOverlays: [ImageEditorSavedPath] {
        guard document.areExtrasVisible else { return [] }
        let selectedID = document.selectedSavedPathID
        return document.savedPaths.filter { $0.isVisible || $0.id == selectedID }
    }

    var selectedSavedPathAnchorOverlayItems: [ImageEditorSavedPathAnchorOverlayItem] {
        guard document.areExtrasVisible, let savedPath = selectedSavedPath else { return [] }
        return savedPath.subpaths.enumerated().flatMap { subpathIndex, anchors in
            anchors.enumerated().map { anchorIndex, anchor in
                ImageEditorSavedPathAnchorOverlayItem(
                    subpathIndex: subpathIndex,
                    anchorIndex: anchorIndex,
                    point: anchor.point,
                    inControl: anchor.inControl,
                    outControl: anchor.outControl
                )
            }
        }
    }

    var hasEditableCurrentPath: Bool {
        currentPathSnapshot(id: UUID(), name: "Path") != nil
    }

    var canSaveCurrentPath: Bool {
        hasEditableCurrentPath
            && document.savedPaths.count < ImageEditorSavedPath.maximumCount
    }

    var canLoadSelectionFromSelectedSavedPath: Bool {
        guard let savedPath = selectedSavedPath, savedPath.isClosed else { return false }
        return !savedPath.subpaths.isEmpty && savedPath.subpaths.allSatisfy { $0.count >= 3 }
    }

    var canFillSelectedSavedPathToPixelLayer: Bool {
        guard canRenderSelectedSavedPathToPixelLayer,
              let savedPath = selectedSavedPath,
              savedPath.isClosed
        else { return false }
        return savedPath.subpaths.allSatisfy { $0.count >= 3 }
    }

    var canStrokeSelectedSavedPathToPixelLayer: Bool {
        guard canRenderSelectedSavedPathToPixelLayer,
              let savedPath = selectedSavedPath
        else { return false }
        return savedPath.subpaths.allSatisfy { $0.count >= 2 }
    }

    @discardableResult
    func saveCurrentPath(name: String?) -> ImageEditorSavedPath? {
        guard document.savedPaths.count < ImageEditorSavedPath.maximumCount else {
            statusText = L10n.text("imageEditor.status.savedPathLimitReached")
            return nil
        }
        let resolvedName = normalizedSavedPathName(name) ?? nextSavedPathName()
        guard let savedPath = currentPathSnapshot(id: UUID(), name: resolvedName) else {
            statusText = L10n.text("imageEditor.status.savedPathRequiresPath")
            return nil
        }

        pushUndo()
        document.savedPaths.append(savedPath)
        document.selectedSavedPathID = savedPath.id
        appendHistory(L10n.text("imageEditor.history.savedPathCreate"))
        statusText = L10n.format("imageEditor.status.savedPathCreated", savedPath.name)
        return savedPath
    }

    @discardableResult
    func selectSavedPath(_ id: UUID) -> Bool {
        guard let savedPath = document.savedPaths.first(where: { $0.id == id }) else {
            statusText = L10n.text("imageEditor.status.savedPathMissing")
            return false
        }
        document.selectedSavedPathID = id
        statusText = L10n.format("imageEditor.status.savedPathSelected", savedPath.name)
        return true
    }

    @discardableResult
    func setSavedPathVisibility(_ id: UUID, isVisible: Bool) -> Bool {
        guard let index = document.savedPaths.firstIndex(where: { $0.id == id }) else {
            statusText = L10n.text("imageEditor.status.savedPathMissing")
            return false
        }
        guard document.savedPaths[index].isVisible != isVisible else { return true }
        document.savedPaths[index].isVisible = isVisible
        statusText = L10n.format(
            isVisible
                ? "imageEditor.status.savedPathVisible"
                : "imageEditor.status.savedPathHidden",
            document.savedPaths[index].name
        )
        return true
    }

    @discardableResult
    func renameSavedPath(_ id: UUID, to name: String) -> Bool {
        guard let index = document.savedPaths.firstIndex(where: { $0.id == id }) else {
            statusText = L10n.text("imageEditor.status.savedPathMissing")
            return false
        }
        guard let normalizedName = normalizedSavedPathName(name) else {
            statusText = L10n.text("imageEditor.status.savedPathNameRequired")
            return false
        }
        guard document.savedPaths[index].name != normalizedName else { return true }

        pushUndo()
        document.savedPaths[index].name = normalizedName
        document.selectedSavedPathID = id
        appendHistory(L10n.text("imageEditor.history.savedPathRename"))
        statusText = L10n.format("imageEditor.status.savedPathRenamed", normalizedName)
        return true
    }

    @discardableResult
    func updateSavedPath(_ id: UUID) -> Bool {
        guard let index = document.savedPaths.firstIndex(where: { $0.id == id }) else {
            statusText = L10n.text("imageEditor.status.savedPathMissing")
            return false
        }
        let existing = document.savedPaths[index]
        guard let snapshot = currentPathSnapshot(
            id: id,
            name: existing.name,
            isVisible: existing.isVisible
        ) else {
            statusText = L10n.text("imageEditor.status.savedPathRequiresPath")
            return false
        }
        guard document.savedPaths[index] != snapshot else { return true }

        pushUndo()
        document.savedPaths[index] = snapshot
        document.selectedSavedPathID = id
        appendHistory(L10n.text("imageEditor.history.savedPathUpdate"))
        statusText = L10n.format("imageEditor.status.savedPathUpdated", existing.name)
        return true
    }

    @discardableResult
    func deleteSavedPath(_ id: UUID) -> Bool {
        guard let index = document.savedPaths.firstIndex(where: { $0.id == id }) else {
            statusText = L10n.text("imageEditor.status.savedPathMissing")
            return false
        }
        let name = document.savedPaths[index].name
        pushUndo()
        document.savedPaths.remove(at: index)
        if document.selectedSavedPathID == id {
            if document.savedPaths.isEmpty {
                document.selectedSavedPathID = nil
            } else {
                document.selectedSavedPathID = document.savedPaths[
                    min(index, document.savedPaths.count - 1)
                ].id
            }
        }
        appendHistory(L10n.text("imageEditor.history.savedPathDelete"))
        statusText = L10n.format("imageEditor.status.savedPathDeleted", name)
        return true
    }

    @discardableResult
    func loadSavedPath(_ id: UUID) -> ImageEditorLayer? {
        guard let savedPath = document.savedPaths.first(where: { $0.id == id }),
              let layer = editableLayer(from: savedPath)
        else {
            statusText = L10n.text("imageEditor.status.savedPathMissing")
            return nil
        }

        pushUndo()
        let insertionIndex = min(
            (document.selectedLayerIndex ?? (document.layers.count - 1)) + 1,
            document.layers.count
        )
        document.layers.insert(layer, at: insertionIndex)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        document.selectedSavedPathID = id
        selectedPathSubpathIndex = 0
        selectedPathAnchorIndex = savedPath.subpaths.first?.isEmpty == false ? 0 : nil
        selectedPathControlRole = .anchor
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.savedPathLoad"))
        statusText = L10n.format("imageEditor.status.savedPathLoaded", savedPath.name)
        return layer
    }

    @discardableResult
    func loadSelectionFromSavedPath(_ id: UUID) -> Bool {
        guard let savedPath = document.savedPaths.first(where: { $0.id == id }) else {
            statusText = L10n.text("imageEditor.status.savedPathMissing")
            return false
        }
        guard savedPath.isClosed,
              let selection = pathSelection(from: savedPath)
        else {
            statusText = L10n.text("imageEditor.status.savedPathSelectionRequiresClosed")
            return false
        }
        return applyPathSelection(
            selection,
            replaceHistoryKey: "imageEditor.history.selectionFromSavedPath",
            successStatus: L10n.format("imageEditor.status.selectionFromSavedPath", savedPath.name)
        )
    }

    @discardableResult
    func fillSavedPathToSelectedPixelLayer(_ id: UUID) -> Bool {
        guard let savedPath = document.savedPaths.first(where: { $0.id == id }) else {
            statusText = L10n.text("imageEditor.status.savedPathMissing")
            return false
        }
        guard savedPath.isClosed else {
            statusText = L10n.text("imageEditor.status.savedPathFillRequiresClosed")
            return false
        }
        guard let targetIndex = selectedSavedPathPixelTargetIndex,
              let image = pathFillImage(
                from: savedPath,
                targetLayer: document.layers[targetIndex]
              )
        else {
            statusText = L10n.text("imageEditor.status.savedPathRenderRequiresPixelLayer")
            return false
        }
        return applyPathRenderedImage(
            image,
            targetIndex: targetIndex,
            historyKey: "imageEditor.history.savedPathFill",
            successStatus: L10n.format("imageEditor.status.savedPathFilled", savedPath.name)
        )
    }

    @discardableResult
    func strokeSavedPathToSelectedPixelLayer(_ id: UUID) -> Bool {
        guard let savedPath = document.savedPaths.first(where: { $0.id == id }) else {
            statusText = L10n.text("imageEditor.status.savedPathMissing")
            return false
        }
        guard let targetIndex = selectedSavedPathPixelTargetIndex,
              let image = pathStrokeImage(
                from: savedPath,
                targetLayer: document.layers[targetIndex]
              )
        else {
            statusText = L10n.text("imageEditor.status.savedPathRenderRequiresPixelLayer")
            return false
        }
        return applyPathRenderedImage(
            image,
            targetIndex: targetIndex,
            historyKey: "imageEditor.history.savedPathStroke",
            successStatus: L10n.format("imageEditor.status.savedPathStroked", savedPath.name)
        )
    }

    func savedPathSummary(_ savedPath: ImageEditorSavedPath) -> String {
        L10n.format(
            savedPath.isClosed
                ? "imageEditor.savedPath.summary.closed"
                : "imageEditor.savedPath.summary.open",
            savedPath.anchorCount,
            savedPath.subpaths.count
        )
    }

    private func currentPathSnapshot(
        id: UUID,
        name: String,
        isVisible: Bool = false
    ) -> ImageEditorSavedPath? {
        guard let layer = document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path
        else { return nil }
        let subpaths = content.allEditablePathSubpaths.map { anchors in
            anchors.map { anchor in
                canvasAnchor(anchor, layer: layer)
            }
        }
        return ImageEditorSavedPath(
            id: id,
            name: name,
            subpaths: subpaths,
            isClosed: content.isPathClosed,
            isVisible: isVisible
        ).normalized(canvasSize: document.canvasSize)
    }

    private func editableLayer(
        from savedPath: ImageEditorSavedPath
    ) -> ImageEditorLayer? {
        guard let primarySubpath = savedPath.subpaths.first,
              primarySubpath.count >= 2
        else { return nil }
        let strokeWidth = max(1, min(96, brushSize * 0.35))
        let points = savedPath.subpaths.flatMap { subpath in
            subpath.flatMap { anchor in
                [anchor.point, anchor.inControl, anchor.outControl].compactMap { $0 }
            }
        }
        guard let minX = points.map(\.x).min(),
              let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(),
              let maxY = points.map(\.y).max()
        else { return nil }
        let padding = ceil(strokeWidth / 2 + 3)
        let frame = CGRect(
            x: max(0, minX - padding),
            y: max(0, minY - padding),
            width: max(1, min(document.canvasSize.width, maxX + padding) - max(0, minX - padding)),
            height: max(1, min(document.canvasSize.height, maxY + padding) - max(0, minY - padding))
        )
        let localSubpaths = savedPath.subpaths.map { subpath in
            subpath.map { localAnchor($0, frame: frame) }
        }
        let localPrimary = localSubpaths.first ?? []
        let content = ImageEditorShapeContent(
            kind: .path,
            fillColor: foregroundColor,
            fillOpacity: 0,
            strokeColor: foregroundColor,
            strokeWidth: strokeWidth,
            strokeOpacity: min(1, max(0.35, opacity)),
            pathPoints: localPrimary.map(\.point),
            pathAnchors: localPrimary,
            pathSubpaths: Array(localSubpaths.dropFirst()),
            isPathClosed: savedPath.isClosed
        )
        var layer = ImageEditorLayer.shape(
            name: savedPath.name,
            frame: frame,
            content: content
        )
        layer.opacity = 1
        layer.groupID = document.selectedLayer?.groupID
        return layer
    }

    private func canvasAnchor(
        _ anchor: ImageEditorPathAnchor,
        layer: ImageEditorLayer
    ) -> ImageEditorPathAnchor {
        ImageEditorPathAnchor(
            point: canvasPoint(anchor.point, layer: layer),
            inControl: anchor.inControl.map { canvasPoint($0, layer: layer) },
            outControl: anchor.outControl.map { canvasPoint($0, layer: layer) }
        )
    }

    private func canvasPoint(_ point: CGPoint, layer: ImageEditorLayer) -> CGPoint {
        CGPoint(
            x: layer.frame.minX + point.x / max(layer.image.size.width, 1) * layer.frame.width,
            y: layer.frame.minY + point.y / max(layer.image.size.height, 1) * layer.frame.height
        )
    }

    private func localAnchor(
        _ anchor: ImageEditorPathAnchor,
        frame: CGRect
    ) -> ImageEditorPathAnchor {
        ImageEditorPathAnchor(
            point: localPoint(anchor.point, frame: frame),
            inControl: anchor.inControl.map { localPoint($0, frame: frame) },
            outControl: anchor.outControl.map { localPoint($0, frame: frame) }
        )
    }

    private func localPoint(_ point: CGPoint, frame: CGRect) -> CGPoint {
        CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
    }

    private func normalizedSavedPathName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(ImageEditorSavedPath.maximumNameLength))
    }

    private var canRenderSelectedSavedPathToPixelLayer: Bool {
        selectedSavedPath != nil && selectedSavedPathPixelTargetIndex != nil
    }

    private var selectedSavedPathPixelTargetIndex: Int? {
        guard selectedLayerCount == 1,
              let targetIndex = document.selectedLayerIndex,
              document.layers[targetIndex].kind.isPixel,
              !document.isEffectivelyPixelsLocked(document.layers[targetIndex])
        else { return nil }
        return targetIndex
    }

    private func nextSavedPathName() -> String {
        let existingNames = Set(document.savedPaths.map(\.name))
        var index = 1
        while existingNames.contains(L10n.format("imageEditor.savedPath.defaultName", index)) {
            index += 1
        }
        return L10n.format("imageEditor.savedPath.defaultName", index)
    }
}
