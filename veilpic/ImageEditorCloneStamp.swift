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
    static let minimumScalePercent: CGFloat = 25
    static let maximumScalePercent: CGFloat = 400
    static let minimumRotationDegrees: CGFloat = -180
    static let maximumRotationDegrees: CGFloat = 180

    var sourcePoint: CGPoint?
    var alignedCanvasOffset: CGSize?
    var flipsHorizontally = false
    var flipsVertically = false
    var horizontalScalePercent: CGFloat = 100
    var verticalScalePercent: CGFloat = 100
    var scalesLinked = true
    var rotationDegrees: CGFloat = 0

    mutating func setUniformScalePercent(_ percent: CGFloat) {
        let bounded = Self.boundedScalePercent(percent)
        horizontalScalePercent = bounded
        verticalScalePercent = bounded
    }

    mutating func setHorizontalScalePercent(_ percent: CGFloat) {
        guard scalesLinked else {
            horizontalScalePercent = Self.boundedScalePercent(percent)
            return
        }
        let ratio = verticalScalePercent / horizontalScalePercent
        horizontalScalePercent = Self.boundedLinkedPrimaryScale(
            percent,
            secondaryRatio: ratio
        )
        verticalScalePercent = horizontalScalePercent * ratio
    }

    mutating func setVerticalScalePercent(_ percent: CGFloat) {
        guard scalesLinked else {
            verticalScalePercent = Self.boundedScalePercent(percent)
            return
        }
        let ratio = horizontalScalePercent / verticalScalePercent
        verticalScalePercent = Self.boundedLinkedPrimaryScale(
            percent,
            secondaryRatio: ratio
        )
        horizontalScalePercent = verticalScalePercent * ratio
    }

    mutating func configureScale(
        horizontalPercent: CGFloat?,
        verticalPercent: CGFloat?,
        linked: Bool?
    ) {
        if let linked { scalesLinked = linked }
        if let horizontalPercent, let verticalPercent {
            horizontalScalePercent = Self.boundedScalePercent(horizontalPercent)
            verticalScalePercent = Self.boundedScalePercent(verticalPercent)
        } else if let horizontalPercent {
            setHorizontalScalePercent(horizontalPercent)
        } else if let verticalPercent {
            setVerticalScalePercent(verticalPercent)
        }
    }

    mutating func setRotationDegrees(_ degrees: CGFloat) {
        guard degrees.isFinite else {
            rotationDegrees = 0
            return
        }
        rotationDegrees = min(
            Self.maximumRotationDegrees,
            max(Self.minimumRotationDegrees, degrees)
        )
    }

    private static func boundedScalePercent(_ percent: CGFloat) -> CGFloat {
        guard percent.isFinite else { return 100 }
        return min(maximumScalePercent, max(minimumScalePercent, percent))
    }

    private static func boundedLinkedPrimaryScale(
        _ percent: CGFloat,
        secondaryRatio: CGFloat
    ) -> CGFloat {
        let boundedRatio = max(0.0001, secondaryRatio)
        let lowerBound = max(minimumScalePercent, minimumScalePercent / boundedRatio)
        let upperBound = min(maximumScalePercent, maximumScalePercent / boundedRatio)
        return min(upperBound, max(lowerBound, boundedScalePercent(percent)))
    }
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
    var sourceHeight: CGFloat? = nil
    var sourceRotationDegrees: CGFloat = 0
    var destinationDiameter: CGFloat? = nil

    var connector: Connector? {
        guard let destinationPoint else { return nil }
        let delta = CGVector(
            dx: destinationPoint.x - sourcePoint.x,
            dy: destinationPoint.y - sourcePoint.y
        )
        let distance = hypot(delta.dx, delta.dy)
        guard distance > 0 else { return nil }
        let unit = CGVector(dx: delta.dx / distance, dy: delta.dy / distance)
        let sourceRadius = ellipseRadius(
            width: diameter,
            height: sourceHeight ?? diameter,
            unit: unit
        )
        let destinationRadius = max(0, destinationDiameter ?? diameter) / 2
        guard distance > sourceRadius + destinationRadius else { return nil }
        return Connector(
            start: CGPoint(
                x: sourcePoint.x + unit.dx * sourceRadius,
                y: sourcePoint.y + unit.dy * sourceRadius
            ),
            end: CGPoint(
                x: destinationPoint.x - unit.dx * destinationRadius,
                y: destinationPoint.y - unit.dy * destinationRadius
            )
        )
    }

    private func ellipseRadius(width: CGFloat, height: CGFloat, unit: CGVector) -> CGFloat {
        let horizontalRadius = max(0.0001, width / 2)
        let verticalRadius = max(0.0001, height / 2)
        return 1 / hypot(unit.dx / horizontalRadius, unit.dy / verticalRadius)
    }

    static func resolve(
        sourcePoint: CGPoint,
        liveSourcePoint: CGPoint?,
        currentDestination: CGPoint?,
        isPickingSource: Bool,
        brushDiameter: CGFloat,
        horizontalSourceScale: CGFloat = 1,
        verticalSourceScale: CGFloat = 1,
        sourceRotationDegrees: CGFloat = 0,
        pressure: CGFloat?,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat
    ) -> ImageEditorSampledBrushOverlayGeometry {
        let destinationDiameter = resolvedDiameter(
            brushDiameter: brushDiameter,
            pressure: pressure,
            pressureControlsSize: pressureControlsSize,
            pressureSensitivity: pressureSensitivity
        )
        let boundedHorizontalScale = horizontalSourceScale.isFinite
            ? max(0.01, horizontalSourceScale)
            : 1
        let boundedVerticalScale = verticalSourceScale.isFinite
            ? max(0.01, verticalSourceScale)
            : 1
        let sourceWidth = destinationDiameter / boundedHorizontalScale
        let sourceHeight = destinationDiameter / boundedVerticalScale
        let boundedRotationDegrees = sourceRotationDegrees.isFinite
            ? sourceRotationDegrees
            : 0

        guard !isPickingSource,
              let liveSourcePoint,
              let currentDestination else {
            return ImageEditorSampledBrushOverlayGeometry(
                sourcePoint: sourcePoint,
                destinationPoint: nil,
                diameter: sourceWidth,
                sourceHeight: sourceHeight,
                sourceRotationDegrees: boundedRotationDegrees,
                destinationDiameter: destinationDiameter
            )
        }

        return ImageEditorSampledBrushOverlayGeometry(
            sourcePoint: liveSourcePoint,
            destinationPoint: currentDestination,
            diameter: sourceWidth,
            sourceHeight: sourceHeight,
            sourceRotationDegrees: boundedRotationDegrees,
            destinationDiameter: destinationDiameter
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

struct ImageEditorCloneStampOverlayGeometry: Equatable {
    var canvasOffset: CGSize
    var destinationReference: CGPoint
    var targetFrame: CGRect
    var horizontalScale: CGFloat
    var verticalScale: CGFloat
    var flipsHorizontally: Bool
    var flipsVertically: Bool
    var rotationDegrees: CGFloat

    func transformedCanvasPoint(fromSourceCanvasPoint sourcePoint: CGPoint) -> CGPoint {
        let shifted = CGPoint(
            x: sourcePoint.x - canvasOffset.width,
            y: sourcePoint.y - canvasOffset.height
        )
        let local = CGVector(
            dx: shifted.x - destinationReference.x,
            dy: shifted.y - destinationReference.y
        )
        let scaled = CGVector(
            dx: local.dx * horizontalScale * (flipsHorizontally ? -1 : 1),
            dy: local.dy * verticalScale * (flipsVertically ? -1 : 1)
        )
        let radians = rotationDegrees * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        return CGPoint(
            x: destinationReference.x + scaled.dx * cosine - scaled.dy * sine,
            y: destinationReference.y + scaled.dx * sine + scaled.dy * cosine
        )
    }
}

struct ImageEditorCloneStampOverlayPreview {
    struct BrushClip: Equatable {
        var center: CGPoint
        var diameter: CGFloat

        var canvasRect: CGRect {
            let boundedDiameter = max(1, diameter.isFinite ? diameter : 1)
            return CGRect(
                x: center.x - boundedDiameter / 2,
                y: center.y - boundedDiameter / 2,
                width: boundedDiameter,
                height: boundedDiameter
            )
        }
    }

    var sourceCanvas: NSImage
    var geometry: ImageEditorCloneStampOverlayGeometry
    var opacity: CGFloat
    var invertsColors: Bool
    var brushClip: BrushClip?
}

struct ImageEditorCloneStampOverlaySourceCache {
    var sampleSource: ImageEditorCloneSampleSource
    var layerID: UUID
    var ignoresAdjustmentLayers: Bool
    var image: NSImage
}

@MainActor
extension ImageEditorViewModel {
    func cloneStampOverlayPreview(
        destinationReference: CGPoint,
        isPainting: Bool = false,
        brushCenter: CGPoint? = nil,
        brushDiameter: CGFloat? = nil
    ) -> ImageEditorCloneStampOverlayPreview? {
        guard cloneStampShowsOverlay,
              !cloneStampOverlayAutoHidesWhilePainting || !isPainting,
              !isEditingLayerMask,
              let sourcePoint = cloneSourcePoint,
              let layer = document.selectedLayer,
              !layer.isGroup,
              !layer.isAdjustment,
              !layer.isFilter,
              !layer.isSolidColorFill,
              !layer.isPatternFill,
              !layer.isGradientFill,
              !layer.isText,
              !layer.isShape,
              !document.isEffectivelyPixelsLocked(layer),
              let sourceCanvas = cloneStampOverlaySourceCanvas(for: layer)
        else { return nil }

        let offset = ImageEditorSampledBrushOffsetResolution.resolve(
            sourcePoint: sourcePoint,
            destinationStart: destinationReference,
            isAligned: isCloneStampAligned,
            alignedOffset: cloneStampAlignedCanvasOffset
        ).canvasOffset
        let targetFrame = layer.frame.intersection(
            CGRect(origin: .zero, size: document.canvasSize)
        )
        guard !targetFrame.isNull, targetFrame.width > 0, targetFrame.height > 0 else {
            return nil
        }
        let brushClip: ImageEditorCloneStampOverlayPreview.BrushClip?
        if cloneStampOverlayClipsToBrush,
           let brushCenter,
           let brushDiameter {
            brushClip = .init(center: brushCenter, diameter: brushDiameter)
        } else {
            brushClip = nil
        }
        return ImageEditorCloneStampOverlayPreview(
            sourceCanvas: sourceCanvas,
            geometry: ImageEditorCloneStampOverlayGeometry(
                canvasOffset: offset,
                destinationReference: destinationReference,
                targetFrame: targetFrame,
                horizontalScale: cloneSourceHorizontalScalePercent / 100,
                verticalScale: cloneSourceVerticalScalePercent / 100,
                flipsHorizontally: cloneSourceFlipsHorizontally,
                flipsVertically: cloneSourceFlipsVertically,
                rotationDegrees: cloneSourceRotationDegrees
            ),
            opacity: cloneStampOverlayOpacityPercent / 100,
            invertsColors: cloneStampOverlayInvertsColors,
            brushClip: brushClip
        )
    }

    private func cloneStampOverlaySourceCanvas(for layer: ImageEditorLayer) -> NSImage? {
        if let cache = cachedCloneStampOverlaySource,
           cache.sampleSource == cloneStampSampleSource,
           cache.layerID == layer.id,
           cache.ignoresAdjustmentLayers == cloneStampIgnoresAdjustmentLayers {
            return cache.image
        }

        let image: NSImage?
        switch cloneStampSampleSource {
        case .currentLayer:
            image = NSImage.rendered(size: document.canvasSize, actions: { _ in
                layer.image.draw(
                    in: layer.frame,
                    from: CGRect(origin: .zero, size: layer.image.size),
                    operation: .copy,
                    fraction: 1
                )
            })
        case .currentAndBelow, .allVisible:
            let source: ImageEditorColorSamplerSource = cloneStampSampleSource == .currentAndBelow
                ? .currentAndBelow
                : .composite
            image = document.colorSamplingLayerIDs(
                for: source,
                ignoringAdjustmentLayers: cloneStampIgnoresAdjustmentLayers
            ).map { document.compositedImage(includingOnly: $0) }
        }
        guard let image else { return nil }
        cachedCloneStampOverlaySource = ImageEditorCloneStampOverlaySourceCache(
            sampleSource: cloneStampSampleSource,
            layerID: layer.id,
            ignoresAdjustmentLayers: cloneStampIgnoresAdjustmentLayers,
            image: image
        )
        return image
    }

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
