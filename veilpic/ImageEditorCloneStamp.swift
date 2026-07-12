//
//  ImageEditorCloneStamp.swift
//  veilpic
//
//  Created by Codex on 2026/7/12.
//

import AppKit
import Foundation

enum ImageEditorCloneSampleSource: String, CaseIterable, Identifiable {
    case currentLayer
    case currentAndBelow
    case allVisible

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.cloneSampleSource.\(rawValue)")
    }
}

struct ImageEditorCloneStampOffsetResolution: Equatable {
    var canvasOffset: CGSize
    var nextAlignedOffset: CGSize?

    static func resolve(
        sourcePoint: CGPoint,
        destinationStart: CGPoint,
        isAligned: Bool,
        alignedOffset: CGSize?
    ) -> ImageEditorCloneStampOffsetResolution {
        let initialOffset = CGSize(
            width: sourcePoint.x - destinationStart.x,
            height: sourcePoint.y - destinationStart.y
        )
        let resolvedOffset = isAligned ? (alignedOffset ?? initialOffset) : initialOffset
        return ImageEditorCloneStampOffsetResolution(
            canvasOffset: resolvedOffset,
            nextAlignedOffset: isAligned ? resolvedOffset : nil
        )
    }
}

struct ImageEditorCloneStampSamplingInput {
    var image: NSImage
    var localOffset: CGSize
}

@MainActor
extension ImageEditorViewModel {
    func cloneStampSamplingInput(
        for layer: ImageEditorLayer,
        canvasOffset: CGSize
    ) -> ImageEditorCloneStampSamplingInput? {
        switch cloneStampSampleSource {
        case .currentLayer:
            let localOffset = CGSize(
                width: canvasOffset.width / max(layer.frame.width, 1) * layer.image.size.width,
                height: canvasOffset.height / max(layer.frame.height, 1) * layer.image.size.height
            )
            return ImageEditorCloneStampSamplingInput(
                image: layer.image.normalizedBitmapImage(),
                localOffset: localOffset
            )
        case .currentAndBelow, .allVisible:
            let sourceCanvas: NSImage
            if cloneStampSampleSource == .currentAndBelow {
                guard let selectedIndex = document.selectedLayerIndex else { return nil }
                let includedIDs = Set(document.layers.prefix(selectedIndex + 1).map(\.id))
                sourceCanvas = document.compositedImage(includingOnly: includedIDs)
            } else {
                sourceCanvas = document.compositedImage
            }
            let sourceRect = layer.frame.offsetBy(
                dx: canvasOffset.width,
                dy: canvasOffset.height
            )
            guard let localImage = NSImage.rendered(size: layer.image.size, actions: { rect in
                sourceCanvas.draw(
                    in: rect,
                    from: sourceRect,
                    operation: .copy,
                    fraction: 1
                )
            }) else { return nil }
            return ImageEditorCloneStampSamplingInput(
                image: localImage.normalizedBitmapImage(),
                localOffset: .zero
            )
        }
    }
}
