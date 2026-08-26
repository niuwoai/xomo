//
//  ImageEditorLayerLockContext.swift
//  veilpic
//
//  Created by Codex on 2026/8/27.
//

import Foundation

enum ImageEditorLayerLockKind: String, CaseIterable {
    case full
    case pixels
    case position
    case transparentPixels
}

extension ImageEditorViewModel {
    func canSetLayersLockFromContext(
        _ clickedLayerID: UUID,
        kind: ImageEditorLayerLockKind,
        isLocked: Bool
    ) -> Bool {
        let contextIDs = layerContextSelectionIDs(for: clickedLayerID)
        guard !contextIDs.isEmpty else { return false }
        return document.layers.contains { layer in
            guard contextIDs.contains(layer.id) else { return false }
            switch kind {
            case .full:
                if isLocked {
                    return !layer.isLocked
                }
                return layer.isLocked
                    || layer.locksPixels
                    || layer.locksPosition
                    || layer.locksTransparentPixels
            case .pixels:
                return canTogglePixelsLock(for: layer) && layer.locksPixels != isLocked
            case .position:
                return canTogglePositionLock(for: layer) && layer.locksPosition != isLocked
            case .transparentPixels:
                return canToggleTransparentPixelsLock(for: layer)
                    && layer.locksTransparentPixels != isLocked
            }
        }
    }

    @discardableResult
    func setLayersLockFromContext(
        _ clickedLayerID: UUID,
        kind: ImageEditorLayerLockKind,
        isLocked: Bool
    ) -> Bool {
        guard canSetLayersLockFromContext(
            clickedLayerID,
            kind: kind,
            isLocked: isLocked
        ) else { return false }
        prepareLayerContextSelection(for: clickedLayerID)
        switch (kind, isLocked) {
        case (.full, true):
            lockSelectedLayers()
        case (.full, false):
            unlockSelectedLayers()
        case (.pixels, true):
            lockSelectedLayerPixels()
        case (.pixels, false):
            unlockSelectedLayerPixels()
        case (.position, true):
            lockSelectedLayerPosition()
        case (.position, false):
            unlockSelectedLayerPosition()
        case (.transparentPixels, true):
            lockSelectedLayerTransparentPixels()
        case (.transparentPixels, false):
            unlockSelectedLayerTransparentPixels()
        }
        return true
    }
}
