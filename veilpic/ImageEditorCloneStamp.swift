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

struct ImageEditorCloneSourceSlotState: Equatable {
    static let maximumCount = 5

    var sourcePoint: CGPoint?
    var alignedCanvasOffset: CGSize?
    var flipsHorizontally = false
}

struct ImageEditorSampledBrushOffsetResolution: Equatable {
    var canvasOffset: CGSize
    var nextAlignedOffset: CGSize?

    func sourcePreviewPoint(at destination: CGPoint) -> CGPoint {
        CGPoint(
            x: destination.x + canvasOffset.width,
            y: destination.y + canvasOffset.height
        )
    }

    static func resolve(
        sourcePoint: CGPoint,
        destinationStart: CGPoint,
        isAligned: Bool,
        alignedOffset: CGSize?
    ) -> ImageEditorSampledBrushOffsetResolution {
        let initialOffset = CGSize(
            width: sourcePoint.x - destinationStart.x,
            height: sourcePoint.y - destinationStart.y
        )
        let resolvedOffset = isAligned ? (alignedOffset ?? initialOffset) : initialOffset
        return ImageEditorSampledBrushOffsetResolution(
            canvasOffset: resolvedOffset,
            nextAlignedOffset: isAligned ? resolvedOffset : nil
        )
    }
}

struct ImageEditorSampledBrushOverlayGeometry: Equatable {
    struct Connector: Equatable {
        var start: CGPoint
        var end: CGPoint
    }

    var sourcePoint: CGPoint
    var destinationPoint: CGPoint?
    var diameter: CGFloat

    var connector: Connector? {
        guard let destinationPoint else { return nil }
        let delta = CGVector(
            dx: destinationPoint.x - sourcePoint.x,
            dy: destinationPoint.y - sourcePoint.y
        )
        let distance = hypot(delta.dx, delta.dy)
        let radius = max(0, diameter) / 2
        guard distance > radius * 2, distance > 0 else { return nil }
        let unit = CGVector(dx: delta.dx / distance, dy: delta.dy / distance)
        return Connector(
            start: CGPoint(
                x: sourcePoint.x + unit.dx * radius,
                y: sourcePoint.y + unit.dy * radius
            ),
            end: CGPoint(
                x: destinationPoint.x - unit.dx * radius,
                y: destinationPoint.y - unit.dy * radius
            )
        )
    }

    static func resolve(
        sourcePoint: CGPoint,
        liveSourcePoint: CGPoint?,
        currentDestination: CGPoint?,
        isPickingSource: Bool,
        brushDiameter: CGFloat,
        pressure: CGFloat?,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat
    ) -> ImageEditorSampledBrushOverlayGeometry {
        let diameter = resolvedDiameter(
            brushDiameter: brushDiameter,
            pressure: pressure,
            pressureControlsSize: pressureControlsSize,
            pressureSensitivity: pressureSensitivity
        )

        guard !isPickingSource,
              let liveSourcePoint,
              let currentDestination else {
            return ImageEditorSampledBrushOverlayGeometry(
                sourcePoint: sourcePoint,
                destinationPoint: nil,
                diameter: diameter
            )
        }

        return ImageEditorSampledBrushOverlayGeometry(
            sourcePoint: liveSourcePoint,
            destinationPoint: currentDestination,
            diameter: diameter
        )
    }

    private static func resolvedDiameter(
        brushDiameter: CGFloat,
        pressure: CGFloat?,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat
    ) -> CGFloat {
        guard pressureControlsSize, let pressure else { return max(1, brushDiameter) }
        let mappedPressure = ImageEditorBrushStrokeKernel.mappedPressure(
            pressure,
            sensitivity: pressureSensitivity
        )
        return max(
            1,
            brushDiameter * ImageEditorBrushStrokeKernel.pressureDiameterScale(
                mappedPressure: mappedPressure,
                minimumDiameter: 0
            )
        )
    }
}

struct ImageEditorSampledBrushInput {
    var image: NSImage
    var localOffset: CGSize
}

@MainActor
extension ImageEditorViewModel {
    func sampledBrushInput(
        for layer: ImageEditorLayer,
        canvasOffset: CGSize,
        sampleSource: ImageEditorCloneSampleSource,
        ignoringAdjustmentLayers: Bool = false
    ) -> ImageEditorSampledBrushInput? {
        switch sampleSource {
        case .currentLayer:
            let localOffset = CGSize(
                width: canvasOffset.width / max(layer.frame.width, 1) * layer.image.size.width,
                height: canvasOffset.height / max(layer.frame.height, 1) * layer.image.size.height
            )
            return ImageEditorSampledBrushInput(
                image: layer.image.normalizedBitmapImage(),
                localOffset: localOffset
            )
        case .currentAndBelow, .allVisible:
            let colorSamplerSource: ImageEditorColorSamplerSource =
                sampleSource == .currentAndBelow
                    ? .currentAndBelow
                    : .composite
            guard let includedIDs = document.colorSamplingLayerIDs(
                for: colorSamplerSource,
                ignoringAdjustmentLayers: ignoringAdjustmentLayers
            ) else { return nil }
            let sourceCanvas = document.compositedImage(
                includingOnly: includedIDs
            )
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
            return ImageEditorSampledBrushInput(
                image: localImage.normalizedBitmapImage(),
                localOffset: .zero
            )
        }
    }
}
