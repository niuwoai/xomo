//
//  ImageEditorRasterize.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit

enum ImageEditorRasterizeTarget: String, CaseIterable, Identifiable {
    case type
    case shape
    case fillContent
    case vectorMask
    case smartObject
    case layerStyle
    case layer

    var id: String { rawValue }

    var actionTitleKey: String {
        "imageEditor.action.layerRasterize.\(rawValue)"
    }
}

@MainActor
extension ImageEditorViewModel {
    var canRasterizeSelectedLayer: Bool {
        canRasterizeSelectedLayers(.layer)
    }

    func canRasterizeSelectedLayers(_ target: ImageEditorRasterizeTarget) -> Bool {
        if target == .vectorMask {
            return canRasterizeSelectedVectorMask
        }
        return !rasterizableLayerIndices(
            for: target,
            selectedIDs: selectedLayerIDsForRasterization
        ).isEmpty
    }

    func canRasterizeLayersFromContext(
        _ clickedLayerID: UUID,
        target: ImageEditorRasterizeTarget
    ) -> Bool {
        let selectedIDs = layerContextSelectionIDs(for: clickedLayerID)
        if target == .vectorMask {
            return canRasterizeVectorMasks(selectedIDs: selectedIDs)
        }
        return !rasterizableLayerIndices(for: target, selectedIDs: selectedIDs).isEmpty
    }

    func rasterizeSelectedLayer() {
        rasterizeSelectedLayers(.layer)
    }

    func rasterizeSelectedLayers(_ target: ImageEditorRasterizeTarget) {
        if target == .vectorMask {
            rasterizeSelectedVectorMask()
            return
        }

        let indices = rasterizableLayerIndices(
            for: target,
            selectedIDs: selectedLayerIDsForRasterization
        )
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for index in indices {
            document.layers[index] = rasterizedLayer(document.layers[index], target: target)
        }
        isEditingLayerMask = false

        recordRasterizationResult(target: target, count: indices.count)
    }

    @discardableResult
    func rasterizeLayersFromContext(
        _ clickedLayerID: UUID,
        target: ImageEditorRasterizeTarget
    ) -> Bool {
        guard canRasterizeLayersFromContext(clickedLayerID, target: target) else {
            return false
        }
        prepareLayerContextSelection(for: clickedLayerID)
        rasterizeSelectedLayers(target)
        return true
    }

    private var selectedLayerIDsForRasterization: Set<UUID> {
        document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
    }

    private func rasterizableLayerIndices(
        for target: ImageEditorRasterizeTarget,
        selectedIDs: Set<UUID>
    ) -> [Int] {
        return document.layers.indices.filter { index in
            selectedIDs.contains(document.layers[index].id)
                && isLayerRasterizable(document.layers[index], target: target)
        }
    }

    private func isLayerRasterizable(
        _ layer: ImageEditorLayer,
        target: ImageEditorRasterizeTarget
    ) -> Bool {
        guard !layer.isGroup,
              !layer.isAdjustment,
              !layer.isFilter,
              !document.isEffectivelyPixelsLocked(layer)
        else { return false }

        switch target {
        case .type:
            return layer.isText
        case .shape:
            return layer.isShape
        case .fillContent:
            return layer.isShape || isGeneratedFillLayer(layer)
        case .vectorMask:
            return canRasterizeVectorMaskContent(layer)
        case .smartObject:
            return layer.isSmartObject
        case .layerStyle:
            return layer.hasLayerEffects
        case .layer:
            return layer.isText
                || layer.isShape
                || isGeneratedFillLayer(layer)
                || layer.isSmartObject
                || layer.hasSmartFilters
                || canRasterizeVectorMaskContent(layer)
        }
    }

    private func rasterizedLayer(
        _ source: ImageEditorLayer,
        target: ImageEditorRasterizeTarget
    ) -> ImageEditorLayer {
        var output = source
        switch target {
        case .type, .shape:
            output.image = baseContentImage(for: source).normalizedBitmapImage()
            output.kind = .pixel
        case .fillContent:
            output.image = baseContentImage(for: source).normalizedBitmapImage()
            output.kind = .pixel
            if source.isShape,
               output.vectorMask == nil,
               let shape = source.shapeContent {
                output.vectorMask = editableVectorMask(from: shape, size: output.image.size)
                output.isVectorMaskEnabled = true
            }
        case .smartObject:
            output = rasterizedSmartObject(source)
        case .layerStyle:
            output = rasterizedLayerStyle(source)
        case .layer:
            if source.isSmartObject {
                output = rasterizedSmartObject(source)
            } else if source.isText || source.isShape || isGeneratedFillLayer(source) || source.hasSmartFilters
                        || source.postFilterCutoutMask != nil {
                let content = source.contentImage.applyingAlphaMask(
                    source.postFilterCutoutMask ?? .opaqueMask(size: source.image.size)
                ) ?? source.contentImage
                output.image = content.normalizedBitmapImage()
                output.kind = .pixel
                output.smartFilters = []
            }
            rasterizeVectorMaskContent(in: &output)
            output.postFilterCutoutMask = nil
        case .vectorMask:
            rasterizeVectorMaskContent(in: &output)
        }
        return output
    }

    private func recordRasterizationResult(target: ImageEditorRasterizeTarget, count: Int) {
        if target == .layerStyle {
            if count == 1 {
                appendHistory(L10n.text("imageEditor.history.layerStyleRasterize"))
                statusText = L10n.text("imageEditor.status.layerStyleRasterized")
            } else {
                appendHistory(L10n.text("imageEditor.history.layerStyleRasterizeSelected"))
                statusText = L10n.format("imageEditor.status.layerStyleRasterizedSelected", count)
            }
            return
        }

        if count == 1 {
            appendHistory(L10n.text("imageEditor.history.layerRasterize"))
            statusText = L10n.text("imageEditor.status.layerRasterized")
        } else {
            appendHistory(L10n.text("imageEditor.history.layerRasterizeSelected"))
            statusText = L10n.format("imageEditor.status.layerRasterizedSelected", count)
        }
    }

    private func baseContentImage(for layer: ImageEditorLayer) -> NSImage {
        var source = layer
        source.smartFilters = []
        return source.contentImage
    }

    private func rasterizedSmartObject(_ source: ImageEditorLayer) -> ImageEditorLayer {
        var output = source
        let frame = source.frame.standardized
        let targetSize = CGSize(
            width: max(1, frame.width.rounded()),
            height: max(1, frame.height.rounded())
        )
        let originalSize = source.image.size
        let content = source.contentImage.applyingAlphaMask(
            source.postFilterCutoutMask ?? .opaqueMask(size: source.image.size)
        ) ?? source.contentImage
        output.image = (content.resized(to: targetSize) ?? content).normalizedBitmapImage()
        output.mask = source.mask?.resized(to: targetSize)?.normalizedBitmapImage()
        output.vectorMask = source.vectorMask.map {
            scaledVectorMask($0, from: originalSize, to: targetSize)
        }
        output.kind = .pixel
        output.smartFilters = []
        output.postFilterCutoutMask = nil
        return output
    }

    private func rasterizedLayerStyle(_ source: ImageEditorLayer) -> ImageEditorLayer {
        var output = source
        // These inputs are evaluated before layer effects, so they must be baked with the style.
        // Layer opacity, blend mode, underlying Blend If, and clipping remain outer compositing state.
        output.image = source
            .renderedCompositingImage(globalLightAngle: document.globalLightAngle)
            .normalizedBitmapImage()
        output.frame = source.renderedCompositingFrame(globalLightAngle: document.globalLightAngle)
        output.mask = nil
        output.vectorMask = nil
        output.isMaskEnabled = true
        output.isMaskLinked = true
        output.maskDensity = 1
        output.maskFeather = 0
        output.postFilterCutoutMask = nil
        output.isVectorMaskEnabled = true
        output.isVectorMaskInverted = false
        output.style = ImageEditorLayerStyle()
        output.smartFilters = []
        output.fillOpacity = 1
        output.blendIfSourceBlack = 0
        output.blendIfSourceWhite = 1
        output.kind = .pixel
        return output
    }

    private func rasterizeVectorMaskContent(in layer: inout ImageEditorLayer) {
        guard canRasterizeVectorMaskContent(layer),
              let mask = layer.effectiveMask
        else { return }
        layer.mask = mask.normalizedBitmapImage()
        layer.vectorMask = nil
        layer.isMaskEnabled = true
        layer.isMaskLinked = true
        layer.isVectorMaskEnabled = true
        layer.isVectorMaskInverted = false
        layer.maskDensity = 1
        layer.maskFeather = 0
    }

    private func canRasterizeVectorMaskContent(_ layer: ImageEditorLayer) -> Bool {
        guard let vectorMask = layer.vectorMask else { return false }
        return layer.isVectorMaskEnabled
            && (layer.mask == nil || layer.isMaskEnabled)
            && vectorMask.kind == .path
            && vectorMask.isPathClosed
            && vectorMask.editablePathAnchors.count >= 3
    }

    private func isGeneratedFillLayer(_ layer: ImageEditorLayer) -> Bool {
        layer.isSolidColorFill || layer.isPatternFill || layer.isGradientFill
    }

    private func editableVectorMask(
        from shape: ImageEditorShapeContent,
        size: CGSize
    ) -> ImageEditorShapeContent {
        let normalized = shape.normalized(size: size)
        if normalized.kind == .path {
            var path = normalized
            path.fillColor = .white
            path.fillOpacity = 1
            path.strokeColor = .white
            path.strokeWidth = 1
            path.strokeOpacity = 0
            return path
        }

        // The generated mask must contain every pixel that the editable shape
        // rendered before rasterization. A fill follows the inset path, while
        // an enabled stroke can extend as far as the shape's outer edge (or
        // beyond it for centered/outside strokes).
        let inset: CGFloat
        if normalized.strokeOpacity > 0 {
            switch normalized.strokePosition {
            case .inside:
                inset = 0
            case .center:
                inset = -normalized.strokeWidth / 2
            case .outside:
                inset = -normalized.strokeWidth
            }
        } else {
            inset = normalized.strokeWidth / 2
        }
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
        let points: [CGPoint]
        if normalized.kind == .ellipse {
            let segmentCount = 64
            points = (0..<segmentCount).map { index in
                let angle = CGFloat(index) / CGFloat(segmentCount) * .pi * 2
                return CGPoint(
                    x: bounds.midX + cos(angle) * bounds.width / 2,
                    y: bounds.midY + sin(angle) * bounds.height / 2
                )
            }
        } else {
            points = [
                CGPoint(x: bounds.minX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.maxY),
                CGPoint(x: bounds.minX, y: bounds.maxY)
            ]
        }
        return ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .white,
            strokeWidth: 1,
            strokeOpacity: 0,
            pathPoints: points,
            pathAnchors: points.map { ImageEditorPathAnchor(point: $0) },
            isPathClosed: true
        ).normalized(size: size)
    }

    private func scaledVectorMask(
        _ source: ImageEditorShapeContent,
        from sourceSize: CGSize,
        to targetSize: CGSize
    ) -> ImageEditorShapeContent {
        let scaleX = targetSize.width / max(1, sourceSize.width)
        let scaleY = targetSize.height / max(1, sourceSize.height)
        let averageScale = (scaleX + scaleY) / 2
        func scalePoint(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * scaleX, y: point.y * scaleY)
        }
        func scaleAnchor(_ anchor: ImageEditorPathAnchor) -> ImageEditorPathAnchor {
            ImageEditorPathAnchor(
                point: scalePoint(anchor.point),
                inControl: anchor.inControl.map { scalePoint($0) },
                outControl: anchor.outControl.map { scalePoint($0) }
            )
        }

        var output = source
        output.strokeWidth = max(ImageEditorShapeContent.minimumStrokeWidth, source.strokeWidth * averageScale)
        output.pathPoints = source.pathPoints.map { scalePoint($0) }
        output.pathAnchors = source.pathAnchors.map { scaleAnchor($0) }
        output.pathSubpaths = source.pathSubpaths.map { anchors in
            anchors.map { scaleAnchor($0) }
        }
        return output.normalized(size: targetSize)
    }
}
