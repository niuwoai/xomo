import AppKit
import Foundation

struct XomoFigmaNodeMaterializationResult {
    var layers: [ImageEditorLayer]
    var slices: [ImageEditorSlice]
    var selectedLayerID: UUID?
    var importedCount: Int
    var omittedCount: Int
}

enum XomoFigmaNodeMaterializer {
    private static let canvasInsetRatio: CGFloat = 0.9
    private static let minimumTileDimension: CGFloat = 0.25
    private static let minimumTileScale: CGFloat = 0.01
    private static let maximumTileScale: CGFloat = 100

    static func renderImageFill(
        _ image: NSImage,
        metadata: XomoFigmaImageFillMetadata,
        size: CGSize
    ) -> NSImage {
        bakedImageFill(
            image,
            sourcePixelSize: CGSize(
                width: metadata.sourcePixelSize?.width ?? image.size.width,
                height: metadata.sourcePixelSize?.height ?? image.size.height
            ),
            size: size,
            scaleMode: metadata.scaleMode,
            imageTransform: metadata.imageTransform,
            scalingFactor: metadata.scalingFactor,
            rotation: metadata.rotation,
            importScale: CGFloat(metadata.importScale)
        )
    }

    static func materialize(
        plan: XomoFigmaNodeImportPlan,
        canvasSize: CGSize
    ) -> XomoFigmaNodeMaterializationResult {
        let itemByID = Dictionary(uniqueKeysWithValues: plan.items.map { ($0.sourceID, $0) })
        let childrenByParent = Dictionary(grouping: plan.items) { $0.parentSourceID }
        let groupIDs = Dictionary(uniqueKeysWithValues: plan.items.compactMap { item in
            item.targetKind == .group ? (item.sourceID, UUID()) : nil
        })
        let sourceBounds = importBounds(plan: plan)
        let transform = importTransform(sourceBounds: sourceBounds, canvasSize: canvasSize)
        var layers: [ImageEditorLayer] = []
        var slices: [ImageEditorSlice] = []
        var layerIDsBySource: [String: UUID] = [:]
        var emittedSourceIDs = Set<String>()
        var omittedCount = 0

        func omitMaterializedSubtree(_ item: XomoFigmaNodeImportItem) {
            guard emittedSourceIDs.insert(item.sourceID).inserted else { return }
            for child in childrenByParent[item.sourceID] ?? [] {
                omitMaterializedSubtree(child)
            }
        }

        func parentGroupID(for item: XomoFigmaNodeImportItem) -> UUID? {
            var candidate = item.parentSourceID
            var visited = Set<String>()
            while let sourceID = candidate, visited.insert(sourceID).inserted {
                if let groupID = groupIDs[sourceID] { return groupID }
                candidate = itemByID[sourceID]?.parentSourceID
            }
            return nil
        }

        func emit(_ item: XomoFigmaNodeImportItem) {
            guard emittedSourceIDs.insert(item.sourceID).inserted else { return }
            if item.targetKind == .group,
               let background = makeGroupBackgroundLayer(
                   item: item,
                   transform: transform,
                   groupID: groupIDs[item.sourceID]
               ) {
                layers.append(background)
            }
            if item.sourceType != "BOOLEAN_OPERATION" {
                for child in childrenByParent[item.sourceID] ?? [] {
                    emit(child)
                }
            } else {
                for child in childrenByParent[item.sourceID] ?? [] {
                    omitMaterializedSubtree(child)
                }
            }
            if item.targetKind == .slice || !item.exportPresets.isEmpty {
                if slices.count < ImageEditorSlice.maximumCount,
                   let frame = mappedFrame(item.frame, transform: transform),
                   let slice = ImageEditorSlice(
                       name: item.sourceName,
                       frame: frame,
                       exportPresets: item.exportPresets
                   ).normalized(canvasSize: canvasSize) {
                    slices.append(slice)
                } else {
                    omittedCount += 1
                    if item.targetKind == .slice {
                        return
                    }
                }
                if item.targetKind == .slice {
                    return
                }
            }
            guard var layer = makeLayer(
                item: item,
                canvasSize: canvasSize,
                transform: transform,
                assignedGroupID: groupIDs[item.sourceID],
                parentGroupID: parentGroupID(for: item),
                imageAssets: plan.imageAssets
            ) else {
                omittedCount += 1
                return
            }
            layer.xomoFigmaSourceURL = plan.sourceCanonicalURL
            layers.append(layer)
            layerIDsBySource[item.sourceID] = layer.id
        }

        if let root = itemByID[plan.rootSourceID] {
            emit(root)
        }
        for item in plan.items where !emittedSourceIDs.contains(item.sourceID) {
            emit(item)
        }
        let selectedLayerID = layerIDsBySource[plan.rootSourceID] ?? layers.last?.id
        return XomoFigmaNodeMaterializationResult(
            layers: layers,
            slices: slices,
            selectedLayerID: selectedLayerID,
            importedCount: layers.count + slices.count,
            omittedCount: omittedCount
        )
    }

    private static func makeLayer(
        item: XomoFigmaNodeImportItem,
        canvasSize: CGSize,
        transform: XomoFigmaImportTransform,
        assignedGroupID: UUID?,
        parentGroupID: UUID?,
        imageAssets: [String: XomoFigmaImageAsset]
    ) -> ImageEditorLayer? {
        guard let targetKind = item.targetKind else { return nil }
        var layer: ImageEditorLayer
        switch targetKind {
        case .group:
            layer = ImageEditorLayer.group(name: item.sourceName, size: canvasSize)
            if let assignedGroupID { layer.id = assignedGroupID }
            if let frame = mappedFrame(item.frame, transform: transform) {
                layer.frame = frame
            }
            let clipMask = item.clipsContent
                ? item.frame.flatMap { mappedFrame($0, transform: transform) }
                : nil
            for maskFrame in [clipMask].compactMap({ $0 }) {
                guard let mask = canvasMask(
                    frame: maskFrame,
                    canvasSize: canvasSize,
                    shape: .rectangle
                ) else { continue }
                if let existingMask = layer.mask {
                    layer.mask = combinedCanvasMasks(existingMask, mask)
                } else {
                    layer.mask = mask
                }
            }
            layer.stackLayout = item.stackLayout
        case .text:
            guard let frame = mappedFrame(item.frame, transform: transform),
                  let text = item.text else { return nil }
            layer = makeTextLayer(item: item, text: text, frame: frame, scale: transform.scale)
        case .rectangle, .ellipse:
            guard let frame = mappedFrame(item.frame, transform: transform) else { return nil }
            layer = makeShapeLayer(
                item: item,
                frame: frame,
                kind: targetKind == .rectangle ? .rectangle : .ellipse,
                scale: transform.scale
            )
        case .vector:
            guard let frame = mappedFrame(item.frame, transform: transform),
                  let vectorLayer = makeVectorLayer(item: item, frame: frame, scale: transform.scale)
            else { return nil }
            layer = vectorLayer
        case .image:
            guard let frame = mappedFrame(item.frame, transform: transform),
                  let reference = item.imageReference,
                  let asset = imageAssets[reference]
            else { return nil }
            layer = makeImageLayer(
                item: item,
                asset: asset,
                frame: frame,
                importScale: transform.scale
            )
        case .imagePlaceholder:
            guard let frame = mappedFrame(item.frame, transform: transform) else { return nil }
            layer = makeImagePlaceholderLayer(item: item, frame: frame)
        case .slice:
            return nil
        }
        if let siblingMaskFrame = item.siblingMaskFrame,
           let mappedMaskFrame = mappedFrame(siblingMaskFrame, transform: transform),
           let siblingMaskShape = item.siblingMaskShape,
           let mask = siblingMask(for: layer, mappedFrame: mappedMaskFrame, shape: siblingMaskShape) {
            if let existingMask = layer.mask {
                layer.mask = combinedCanvasMasks(existingMask, mask)
            } else {
                layer.mask = mask
            }
        }
        layer.groupID = parentGroupID
        if item.targetKind != .group {
            applyFigmaEffects(item.effects, to: &layer, scale: transform.scale)
        }
        layer.xomoFigmaVariableBindings = item.variableBindings
        layer.xomoFigmaSourceID = item.sourceID
        layer.xomoFigmaNodeType = item.sourceType
        layer.xomoFigmaComponentRole = item.componentRole
        layer.xomoFigmaComponentProperties = item.componentProperties
        layer.xomoFigmaComponentPropertyDefaults = item.componentProperties
        if let imageReference = item.imageReference {
            layer.xomoFigmaImageFill = XomoFigmaImageFillMetadata(
                imageReference: imageReference,
                scaleMode: item.imageScaleMode,
                imageTransform: item.imageTransform,
                scalingFactor: item.imageScalingFactor,
                rotation: item.imageRotation,
                filters: item.imageFilters,
                sourcePixelSize: imageAssets[imageReference].map {
                    XomoFigmaPlanSize(width: $0.pixelSize.width, height: $0.pixelSize.height)
                },
                importScale: Double(transform.scale)
            )
        }
        layer.stackChildLayout = item.stackChildLayout
        layer.isStackLayoutExcluded = item.isStackLayoutExcluded
        layer.isVisible = item.isVisible
        layer.isLocked = item.isLocked
        if let blendMode = item.blendMode.flatMap(ImageEditorBlendMode.init(rawValue:)) {
            layer.blendMode = blendMode
        }
        if item.isMask {
            layer.isVisible = false
        }
        layer.opacity = min(max(item.opacity, 0), 1)
        return layer
    }

    private static func canvasMask(
        frame: CGRect,
        canvasSize: CGSize,
        shape: XomoFigmaPlanMaskShape
    ) -> NSImage? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        let clippedFrame = frame.intersection(CGRect(origin: .zero, size: canvasSize))
        guard !clippedFrame.isNull, clippedFrame.width > 0, clippedFrame.height > 0 else { return nil }
        return NSImage.rendered(size: canvasSize) { _ in
            let appKitFrame = CGRect(
                x: clippedFrame.minX,
                y: canvasSize.height - clippedFrame.maxY,
                width: clippedFrame.width,
                height: clippedFrame.height
            )
            NSColor.white.setFill()
            switch shape {
            case .rectangle:
                appKitFrame.fill()
            case .ellipse:
                NSBezierPath(ovalIn: appKitFrame).fill()
            }
        }
    }

    private static func siblingMask(
        for layer: ImageEditorLayer,
        mappedFrame: CGRect,
        shape: XomoFigmaPlanMaskShape
    ) -> NSImage? {
        if layer.isGroup {
            return canvasMask(frame: mappedFrame, canvasSize: layer.image.size, shape: shape)
        }
        let localFrame = mappedFrame.offsetBy(dx: -layer.frame.minX, dy: -layer.frame.minY)
        return canvasMask(frame: localFrame, canvasSize: layer.image.size, shape: shape)
    }

    private static func combinedCanvasMasks(_ first: NSImage, _ second: NSImage) -> NSImage? {
        guard first.size == second.size else { return nil }
        return NSImage.rendered(size: first.size) { rect in
            first.draw(
                in: rect,
                from: CGRect(origin: .zero, size: first.size),
                operation: .copy,
                fraction: 1
            )
            second.draw(
                in: rect,
                from: CGRect(origin: .zero, size: second.size),
                operation: .destinationIn,
                fraction: 1
            )
        }
    }

    private static func makeImageLayer(
        item: XomoFigmaNodeImportItem,
        asset: XomoFigmaImageAsset,
        frame: CGRect,
        importScale: CGFloat
    ) -> ImageEditorLayer {
        let size = CGSize(width: max(1, frame.width), height: max(1, frame.height))
        let source = NSImage(data: asset.data) ?? NSImage.transparent(size: size)
        let bakedFill = bakedImageFill(
            source,
            sourcePixelSize: CGSize(width: asset.pixelSize.width, height: asset.pixelSize.height),
            size: size,
            scaleMode: item.imageScaleMode,
            imageTransform: item.imageTransform,
            scalingFactor: item.imageScalingFactor,
            rotation: item.imageRotation,
            importScale: importScale
        )
        var layer = ImageEditorLayer.blank(name: item.sourceName, size: size)
        layer.image = bakedFill
        layer.frame = CGRect(origin: frame.origin, size: size)
        layer.xomoFigmaImageFillSourceImage = source
        return layer
    }

    private static func bakedImageFill(
        _ image: NSImage,
        sourcePixelSize: CGSize,
        size: CGSize,
        scaleMode: String?,
        imageTransform: XomoFigmaPlanTransform?,
        scalingFactor: Double?,
        rotation: Double?,
        importScale: CGFloat
    ) -> NSImage {
        NSImage.rendered(size: size) { rect in
            if scaleMode == "STRETCH" || scaleMode == "CROP" {
                drawTransformedCrop(image, in: rect, transform: imageTransform)
                return
            }
            let rotated = rotatedImage(image, rotation: rotation)
            if scaleMode == "TILE" {
                drawTiledImage(
                    rotated.image,
                    sourcePixelSize: rotatedPixelSize(sourcePixelSize, quarterTurns: rotated.quarterTurns),
                    in: rect,
                    scalingFactor: scalingFactor,
                    importScale: importScale
                )
                return
            }
            let sourceSize = rotated.image.size
            guard sourceSize.width > 0, sourceSize.height > 0 else { return }
            let scale: CGFloat
            switch scaleMode {
            case "FIT":
                scale = min(rect.width / sourceSize.width, rect.height / sourceSize.height)
            default:
                scale = max(rect.width / sourceSize.width, rect.height / sourceSize.height)
            }
            let drawSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
            let drawRect = CGRect(
                x: rect.midX - drawSize.width / 2,
                y: rect.midY - drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            NSBezierPath(rect: rect).addClip()
            rotated.image.draw(in: drawRect, from: .zero, operation: .copy, fraction: 1)
        } ?? NSImage.transparent(size: size)
    }

    private static func drawTransformedCrop(
        _ image: NSImage,
        in rect: CGRect,
        transform: XomoFigmaPlanTransform?
    ) {
        guard let transform,
              image.size.width > 0,
              image.size.height > 0,
              let context = NSGraphicsContext.current
        else {
            image.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
            return
        }
        context.withImageEditorTopLeftCoordinates(height: rect.height) {
            let sourceSize = image.size
            let affine = CGAffineTransform(
                a: rect.width * CGFloat(transform.m11) / sourceSize.width,
                b: rect.height * CGFloat(transform.m21) / sourceSize.width,
                c: rect.width * CGFloat(transform.m12) / sourceSize.height,
                d: rect.height * CGFloat(transform.m22) / sourceSize.height,
                tx: rect.width * CGFloat(transform.translationX),
                ty: rect.height * CGFloat(transform.translationY)
            )
            context.cgContext.clip(to: rect)
            context.cgContext.concatenate(affine)
            image.draw(
                in: CGRect(origin: .zero, size: sourceSize),
                from: .zero,
                operation: .copy,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )
        }
    }

    private static func drawTiledImage(
        _ image: NSImage,
        sourcePixelSize: CGSize,
        in rect: CGRect,
        scalingFactor: Double?,
        importScale: CGFloat
    ) {
        guard sourcePixelSize.width > 0,
              sourcePixelSize.height > 0,
              let tile = image.copy() as? NSImage
        else { return }
        let requestedScale = CGFloat(scalingFactor ?? 1)
        let tileScale = min(max(requestedScale, minimumTileScale), maximumTileScale)
            * max(importScale, minimumTileScale)
        tile.size = CGSize(
            width: max(minimumTileDimension, sourcePixelSize.width * tileScale),
            height: max(minimumTileDimension, sourcePixelSize.height * tileScale)
        )
        NSColor(patternImage: tile).setFill()
        rect.fill()
    }

    private static func rotatedImage(
        _ image: NSImage,
        rotation: Double?
    ) -> (image: NSImage, quarterTurns: Int) {
        let normalized = (rotation ?? 0).truncatingRemainder(dividingBy: 360)
        let quarterTurns = (Int((normalized / 90).rounded()) % 4 + 4) % 4
        guard quarterTurns != 0 else { return (image, 0) }
        let sourceSize = image.size
        let outputSize = quarterTurns.isMultiple(of: 2)
            ? sourceSize
            : CGSize(width: sourceSize.height, height: sourceSize.width)
        let rotated = NSImage.rendered(size: outputSize) { _ in
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: outputSize.height) {
                guard let context = NSGraphicsContext.current else { return }
                context.cgContext.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
                context.cgContext.rotate(by: CGFloat(quarterTurns) * .pi / 2)
                image.draw(
                    in: CGRect(
                        x: -sourceSize.width / 2,
                        y: -sourceSize.height / 2,
                        width: sourceSize.width,
                        height: sourceSize.height
                    ),
                    from: .zero,
                    operation: .copy,
                    fraction: 1,
                    respectFlipped: true,
                    hints: nil
                )
            }
        }
        return (rotated ?? image, quarterTurns)
    }

    private static func rotatedPixelSize(_ size: CGSize, quarterTurns: Int) -> CGSize {
        quarterTurns.isMultiple(of: 2)
            ? size
            : CGSize(width: size.height, height: size.width)
    }

    private static func makeTextLayer(
        item: XomoFigmaNodeImportItem,
        text: XomoFigmaPlanText,
        frame: CGRect,
        scale: CGFloat
    ) -> ImageEditorLayer {
        let padding = ImageEditorTextContent.drawingPadding
        let content = ImageEditorTextContent(
            text: text.characters,
            color: nsColor(item.solidFill, fallback: .black),
            fontSize: max(6, CGFloat(text.fontSize ?? 12) * scale),
            fontFamilyName: text.fontFamily ?? ImageEditorTextContent.systemFontFamilyName,
            point: CGPoint(x: padding, y: padding),
            isBold: XomoFigmaNodeImportMapper.approximatedTextBold(text.fontWeight),
            isItalic: text.isItalic,
            isUnderlined: text.decoration == .underline,
            isStruckThrough: text.decoration == .strikethrough,
            characterSpacing: min(
                ImageEditorTextContent.maximumCharacterSpacing,
                max(
                    ImageEditorTextContent.minimumCharacterSpacing,
                    CGFloat(text.letterSpacing ?? 0) * scale
                )
            ),
            lineSpacing: max(
                0,
                min(
                    ImageEditorTextContent.maximumLineSpacing,
                    CGFloat((text.lineHeight ?? text.fontSize ?? 0) - (text.fontSize ?? 0)) * scale
                )
            ),
            boxWidth: text.usesAutoWidthAndHeight ? 0 : max(1, frame.width - padding * 2),
            boxHeight: text.usesAutoWidthAndHeight || text.usesAutoHeight
                ? 0
                : max(1, frame.height - padding * 2),
            alignment: textAlignment(text.horizontalAlignment),
            firstLineIndent: min(
                ImageEditorTextContent.maximumFirstLineIndent,
                max(0, CGFloat(text.paragraphIndent ?? 0) * scale)
            ),
            paragraphSpacing: min(
                ImageEditorTextContent.maximumParagraphSpacing,
                max(0, CGFloat(text.paragraphSpacing ?? 0) * scale)
            ),
            textCase: text.textCase,
            truncatesOverflow: text.truncatesOverflow,
            verticalAlignment: text.verticalAlignment
        )
        return ImageEditorLayer.text(name: item.sourceName, origin: frame.origin, content: content)
    }

    private static func makeGroupBackgroundLayer(
        item: XomoFigmaNodeImportItem,
        transform: XomoFigmaImportTransform,
        groupID: UUID?
    ) -> ImageEditorLayer? {
        guard item.solidFill != nil || item.linearGradientFill != nil || item.solidStroke != nil,
              let frame = mappedFrame(item.frame, transform: transform)
        else { return nil }
        var layer = ImageEditorLayer.shape(
            name: L10n.format("imageEditor.layer.figmaFrameBackground", item.sourceName),
            frame: frame,
            content: shapeContent(item: item, kind: .rectangle, scale: transform.scale)
        )
        layer.groupID = groupID
        layer.isStackLayoutExcluded = true
        layer.isStackLayoutBackground = true
        applyFigmaEffects(item.effects, to: &layer, scale: transform.scale)
        return layer
    }

    private static func applyFigmaEffects(
        _ effects: [XomoFigmaPlanEffect],
        to layer: inout ImageEditorLayer,
        scale: CGFloat
    ) {
        let scale = max(0.01, scale)
        for effect in effects {
            let color = nsColor(effect.color, fallback: .black)
            let offset = CGSize(
                width: CGFloat(effect.offsetX) * scale,
                height: CGFloat(effect.offsetY) * scale
            )
            let distance = ImageEditorLayerStyle.shadowDistance(from: offset)
            let angle = ImageEditorLayerStyle.shadowAngle(from: offset)
            switch effect.kind {
            case .dropShadow:
                layer.style.shadowEnabled = true
                layer.style.shadowColor = color
                layer.style.shadowOpacity = CGFloat(effect.color.alpha)
                layer.style.shadowBlur = CGFloat(effect.radius) * scale
                layer.style.shadowSpread = CGFloat(effect.spread) * scale
                layer.style.shadowDistance = distance
                layer.style.shadowAngle = angle
                layer.style.shadowOffset = offset
                layer.style.shadowUsesGlobalLight = false
            case .innerShadow:
                layer.style.innerShadowEnabled = true
                layer.style.innerShadowColor = color
                layer.style.innerShadowOpacity = CGFloat(effect.color.alpha)
                layer.style.innerShadowBlur = CGFloat(effect.radius) * scale
                layer.style.innerShadowChoke = CGFloat(effect.spread) * scale
                layer.style.innerShadowDistance = distance
                layer.style.innerShadowAngle = angle
                layer.style.innerShadowUsesGlobalLight = false
            case .layerBlur:
                let radius = max(0, CGFloat(effect.radius) * scale)
                layer.smartFilters.append(
                    ImageEditorSmartFilter(
                        kind: .gaussianBlur,
                        intensity: min(1, radius / 18),
                        settings: ImageEditorFilterSettings(gaussianBlurRadius: Double(radius))
                    )
                )
            case .backgroundBlur:
                let radius = max(0, CGFloat(effect.radius) * scale)
                var filter = ImageEditorSmartFilter(
                    kind: .gaussianBlur,
                    intensity: min(1, radius / 18),
                    settings: ImageEditorFilterSettings(gaussianBlurRadius: Double(radius))
                )
                filter.appliesToBackdrop = true
                layer.smartFilters.append(filter)
            }
        }
    }

    private static func makeShapeLayer(
        item: XomoFigmaNodeImportItem,
        frame: CGRect,
        kind: ImageEditorShapeKind,
        scale: CGFloat
    ) -> ImageEditorLayer {
        ImageEditorLayer.shape(
            name: item.sourceName,
            frame: frame,
            content: shapeContent(item: item, kind: kind, scale: scale)
        )
    }

    private static func makeVectorLayer(
        item: XomoFigmaNodeImportItem,
        frame: CGRect,
        scale: CGFloat
    ) -> ImageEditorLayer? {
        let parsed = item.vectorPaths.compactMap(XomoSVGPathParser.parse)
        guard parsed.count == item.vectorPaths.count, !parsed.isEmpty else { return nil }
        let geometryScale = vectorGeometryScale(item: item, frame: frame, fallbackScale: scale)
        let subpaths = parsed
            .flatMap(\.subpaths)
            .map { anchors in
                anchors.map {
                    scaledAnchor($0, scaleX: geometryScale.width, scaleY: geometryScale.height)
                }
            }
        let transformedSubpaths = transformedVectorSubpaths(
            subpaths,
            transform: item.relativeTransform,
            frame: frame
        )
        guard let primary = transformedSubpaths.first, primary.count >= 2 else { return nil }
        var content = shapeContent(item: item, kind: .path, scale: scale)
        content.pathAnchors = primary
        content.pathPoints = primary.map(\.point)
        content.pathSubpaths = Array(transformedSubpaths.dropFirst())
        content.isPathClosed = parsed.allSatisfy(\.isClosed)
        return ImageEditorLayer.shape(name: item.sourceName, frame: frame, content: content)
    }

    private static func transformedVectorSubpaths(
        _ subpaths: [[ImageEditorPathAnchor]],
        transform: XomoFigmaPlanTransform?,
        frame: CGRect
    ) -> [[ImageEditorPathAnchor]] {
        guard let transform, !isIdentityTransform(transform), !subpaths.isEmpty else {
            return subpaths
        }
        let transformed = subpaths.map { anchors in
            anchors.map { anchor in
                ImageEditorPathAnchor(
                    point: apply(transform, to: anchor.point),
                    inControl: anchor.inControl.map { apply(transform, to: $0) },
                    outControl: anchor.outControl.map { apply(transform, to: $0) }
                )
            }
        }
        let points = transformed.flatMap { anchors in
            anchors.flatMap { anchor in
                [anchor.point, anchor.inControl, anchor.outControl].compactMap { $0 }
            }
        }
        guard let first = points.first else { return subpaths }
        let bounds = points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { partial, point in
            partial.union(CGRect(origin: point, size: .zero))
        }
        guard bounds.width > 0, bounds.height > 0 else { return subpaths }
        return transformed.map { anchors in
            anchors.map { anchor in
                ImageEditorPathAnchor(
                    point: normalizedVectorPoint(anchor.point, bounds: bounds, frame: frame),
                    inControl: anchor.inControl.map { normalizedVectorPoint($0, bounds: bounds, frame: frame) },
                    outControl: anchor.outControl.map { normalizedVectorPoint($0, bounds: bounds, frame: frame) }
                )
            }
        }
    }

    private static func apply(_ transform: XomoFigmaPlanTransform, to point: CGPoint) -> CGPoint {
        CGPoint(
            x: CGFloat(transform.m11) * point.x + CGFloat(transform.m12) * point.y + CGFloat(transform.translationX),
            y: CGFloat(transform.m21) * point.x + CGFloat(transform.m22) * point.y + CGFloat(transform.translationY)
        )
    }

    private static func normalizedVectorPoint(
        _ point: CGPoint,
        bounds: CGRect,
        frame: CGRect
    ) -> CGPoint {
        CGPoint(
            x: (point.x - bounds.minX) / bounds.width * frame.width,
            y: (point.y - bounds.minY) / bounds.height * frame.height
        )
    }

    private static func isIdentityTransform(_ transform: XomoFigmaPlanTransform) -> Bool {
        let epsilon = 0.000_001
        return abs(transform.m11 - 1) <= epsilon
            && abs(transform.m12) <= epsilon
            && abs(transform.m21) <= epsilon
            && abs(transform.m22 - 1) <= epsilon
            && abs(transform.translationX) <= epsilon
            && abs(transform.translationY) <= epsilon
    }

    private static func shapeContent(
        item: XomoFigmaNodeImportItem,
        kind: ImageEditorShapeKind,
        scale: CGFloat
    ) -> ImageEditorShapeContent {
        let fill = nsColor(item.solidFill, fallback: .clear)
        let stroke = nsColor(item.solidStroke, fallback: .clear)
        let linearGradient = item.linearGradientFill.map { value in
            ImageEditorGradientFillContent.shapeLinear(
                colorStops: value.colorStops.map { stop in
                    ImageEditorGradientColorStop(
                        position: stop.position,
                        color: nsColor(stop.color, fallback: .clear)
                    )
                },
                angle: CGFloat(value.angle),
                scale: CGFloat(value.scale)
            )
        }
        let radialGradient = item.radialGradientFill.map { value in
            var gradient = ImageEditorGradientFillContent.shapeLinear(
                colorStops: value.colorStops.map { stop in
                    ImageEditorGradientColorStop(
                        position: stop.position,
                        color: nsColor(stop.color, fallback: .clear)
                    )
                },
                scale: CGFloat(value.scale)
            )
            gradient.style = .radial
            return gradient
        }
        let gradient = linearGradient ?? radialGradient
        let gradientCenter = item.linearGradientFill.map {
            CGPoint(x: $0.centerX, y: $0.centerY)
        } ?? item.radialGradientFill.map {
            CGPoint(x: $0.centerX, y: $0.centerY)
        }
        let gradientOpacity = item.linearGradientFill?.opacity
            ?? item.radialGradientFill?.opacity
        return ImageEditorShapeContent(
            kind: kind,
            fillColor: fill,
            fillGradient: gradient,
            fillGradientCenter: gradientCenter ?? CGPoint(x: 0.5, y: 0.5),
            fillOpacity: gradientOpacity.map { CGFloat($0) }
                ?? item.solidFill.map { CGFloat($0.alpha) }
                ?? 0,
            strokeColor: stroke,
            strokeWidth: max(
                ImageEditorShapeContent.minimumStrokeWidth,
                CGFloat(item.strokeWeight ?? 1) * scale
            ),
            strokeOpacity: item.solidStroke.map { CGFloat($0.alpha) } ?? 0,
            strokePosition: ImageEditorStrokePosition(figmaValue: item.strokeAlign),
            strokeCap: ImageEditorStrokeCap(figmaValue: item.strokeCap),
            strokeJoin: ImageEditorStrokeJoin(figmaValue: item.strokeJoin),
            strokeDashPattern: item.strokeDashes?.map { max(0, CGFloat($0) * scale) } ?? [],
            cornerRadius: max(0, CGFloat(item.cornerRadius ?? 0) * scale),
            cornerRadii: item.cornerRadii?.scaled(by: scale),
            cornerSmoothing: max(0, min(1, CGFloat(item.cornerSmoothing ?? 0)))
        )
    }

    private static func makeImagePlaceholderLayer(
        item: XomoFigmaNodeImportItem,
        frame: CGRect
    ) -> ImageEditorLayer {
        let size = CGSize(width: max(1, frame.width), height: max(1, frame.height))
        var layer = ImageEditorLayer.blank(name: item.sourceName, size: size)
        layer.image = placeholderImage(size: size)
        layer.frame = CGRect(origin: frame.origin, size: size)
        return layer
    }

    private static func placeholderImage(size: CGSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            let tileSize: CGFloat = 12
            let rows = Int(ceil(rect.height / tileSize))
            let columns = Int(ceil(rect.width / tileSize))
            for row in 0..<rows {
                for column in 0..<columns {
                    let color = (row + column).isMultiple(of: 2)
                        ? NSColor(calibratedWhite: 0.78, alpha: 1)
                        : NSColor(calibratedWhite: 0.9, alpha: 1)
                    color.setFill()
                    CGRect(
                        x: CGFloat(column) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    ).fill()
                }
            }
            NSColor.systemOrange.withAlphaComponent(0.75).setStroke()
            let outline = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
            outline.lineWidth = 1
            outline.stroke()
            let diagonal = NSBezierPath()
            diagonal.move(to: CGPoint(x: rect.minX, y: rect.minY))
            diagonal.line(to: CGPoint(x: rect.maxX, y: rect.maxY))
            diagonal.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            diagonal.line(to: CGPoint(x: rect.minX, y: rect.maxY))
            diagonal.lineWidth = 1
            diagonal.stroke()
        } ?? NSImage.transparent(size: size)
    }

    private static func importBounds(plan: XomoFigmaNodeImportPlan) -> CGRect {
        if let rootFrame = plan.items.first(where: { $0.sourceID == plan.rootSourceID })?.frame,
           rootFrame.width > 0,
           rootFrame.height > 0 {
            return cgRect(rootFrame)
        }
        let frames = plan.items.compactMap(\.frame).filter { $0.width > 0 && $0.height > 0 }
        guard let first = frames.first else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        return frames.dropFirst().reduce(cgRect(first)) { $0.union(cgRect($1)) }
    }

    private static func importTransform(
        sourceBounds: CGRect,
        canvasSize: CGSize
    ) -> XomoFigmaImportTransform {
        let availableWidth = max(1, canvasSize.width * canvasInsetRatio)
        let availableHeight = max(1, canvasSize.height * canvasInsetRatio)
        let scale = min(
            1,
            availableWidth / max(1, sourceBounds.width),
            availableHeight / max(1, sourceBounds.height)
        )
        let scaledSize = CGSize(width: sourceBounds.width * scale, height: sourceBounds.height * scale)
        return XomoFigmaImportTransform(
            sourceOrigin: sourceBounds.origin,
            destinationOrigin: CGPoint(
                x: (canvasSize.width - scaledSize.width) / 2,
                y: (canvasSize.height - scaledSize.height) / 2
            ),
            scale: scale
        )
    }

    private static func mappedFrame(
        _ frame: XomoFigmaPlanRect?,
        transform: XomoFigmaImportTransform
    ) -> CGRect? {
        guard let frame, frame.width > 0, frame.height > 0 else { return nil }
        return CGRect(
            x: transform.destinationOrigin.x + (CGFloat(frame.x) - transform.sourceOrigin.x) * transform.scale,
            y: transform.destinationOrigin.y + (CGFloat(frame.y) - transform.sourceOrigin.y) * transform.scale,
            width: CGFloat(frame.width) * transform.scale,
            height: CGFloat(frame.height) * transform.scale
        )
    }

    private static func scaledAnchor(
        _ anchor: ImageEditorPathAnchor,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) -> ImageEditorPathAnchor {
        ImageEditorPathAnchor(
            point: scaledPoint(anchor.point, scaleX: scaleX, scaleY: scaleY),
            inControl: anchor.inControl.map { scaledPoint($0, scaleX: scaleX, scaleY: scaleY) },
            outControl: anchor.outControl.map { scaledPoint($0, scaleX: scaleX, scaleY: scaleY) }
        )
    }

    private static func scaledPoint(_ point: CGPoint, scaleX: CGFloat, scaleY: CGFloat) -> CGPoint {
        CGPoint(x: point.x * scaleX, y: point.y * scaleY)
    }

    private static func vectorGeometryScale(
        item: XomoFigmaNodeImportItem,
        frame: CGRect,
        fallbackScale: CGFloat
    ) -> CGSize {
        guard let size = item.geometrySize, size.width > 0, size.height > 0 else {
            return CGSize(width: fallbackScale, height: fallbackScale)
        }
        return CGSize(
            width: frame.width / CGFloat(size.width),
            height: frame.height / CGFloat(size.height)
        )
    }

    private static func nsColor(_ color: XomoFigmaPlanColor?, fallback: NSColor) -> NSColor {
        guard let color else { return fallback }
        return NSColor(
            srgbRed: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: CGFloat(color.alpha)
        )
    }

    private static func textAlignment(_ rawValue: String?) -> ImageEditorTextAlignment {
        ImageEditorTextAlignment(rawValue: rawValue ?? "") ?? .left
    }

    private static func cgRect(_ rect: XomoFigmaPlanRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }
}

private struct XomoFigmaImportTransform {
    var sourceOrigin: CGPoint
    var destinationOrigin: CGPoint
    var scale: CGFloat
}

extension ImageEditorViewModel {
    @discardableResult
    func importFigmaNodePlan(_ plan: XomoFigmaNodeImportPlan) -> Bool {
        let result = XomoFigmaNodeMaterializer.materialize(plan: plan, canvasSize: document.canvasSize)
        let availableSliceCapacity = max(0, ImageEditorSlice.maximumCount - document.slices.count)
        let importedSlices = Array(result.slices.prefix(availableSliceCapacity))
        let skippedSliceCount = result.slices.count - importedSlices.count
        let importedCount = result.layers.count + importedSlices.count
        let omittedCount = result.omittedCount + skippedSliceCount
        guard importedCount > 0 else {
            statusText = L10n.text("imageEditor.status.figmaNodeImportEmpty")
            return false
        }
        pushUndo()
        if !result.layers.isEmpty {
            let insertionAnchorID = document.selectedLayer.map { selectedLayer in
                document.ancestorGroups(for: selectedLayer).last?.id ?? selectedLayer.id
            }
            let insertionIndex = min(
                (insertionAnchorID.flatMap { anchorID in
                    document.layers.firstIndex { $0.id == anchorID }
                } ?? (document.layers.count - 1)) + 1,
                document.layers.count
            )
            document.layers.insert(contentsOf: result.layers, at: insertionIndex)
            if let selectedLayerID = result.selectedLayerID {
                document.selectedLayerID = selectedLayerID
                document.selectedLayerIDs = [selectedLayerID]
                isEditingLayerMask = false
            }
        }
        if !importedSlices.isEmpty {
            document.slices.append(contentsOf: importedSlices)
            if let firstSlice = importedSlices.first {
                exportSettings.sliceID = firstSlice.id
                if result.layers.isEmpty || !(firstSlice.exportPresets ?? []).isEmpty {
                    exportSettings.scope = .slice
                    applyPrimaryExportPreset(for: firstSlice)
                }
                isSlicesPanelVisible = true
            }
        }
        appendHistory(L10n.text("imageEditor.history.figmaNodeImport"))
        statusText = L10n.format(
            "imageEditor.status.figmaNodeImported",
            importedCount,
            omittedCount
        )
        return true
    }
}
