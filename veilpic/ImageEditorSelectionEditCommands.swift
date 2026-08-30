//
//  ImageEditorSelectionEditCommands.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

enum ImageEditorSelectionFillContents: String, CaseIterable, Identifiable {
    case foreground
    case background
    case black
    case gray50
    case white
    case color
    case pattern
    case contentAware
    case history

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.selectionFill.contents.\(rawValue)")
    }

    func resolvedColor(
        foreground: NSColor,
        background: NSColor,
        custom: NSColor
    ) -> NSColor? {
        switch self {
        case .foreground: foreground
        case .background: background
        case .black: .black
        case .gray50: NSColor(deviceWhite: 0.5, alpha: 1)
        case .white: .white
        case .color: custom
        case .pattern: nil
        case .contentAware: nil
        case .history: nil
        }
    }

    static func availableCases(isQuickMaskMode: Bool) -> [Self] {
        isQuickMaskMode
            ? allCases.filter { $0 != .contentAware && $0 != .history }
            : allCases
    }
}

enum ImageEditorHistoryFillSource: Equatable {
    case entry(UUID)
    case snapshot(UUID)
}

struct ImageEditorSelectionFillOptions {
    var contents: ImageEditorSelectionFillContents = .foreground
    var customColor: NSColor = .black
    var blendMode: ImageEditorBlendMode = .normal
    var opacity: CGFloat = 1
    var preservesTransparency = false
    var patternContent = ImageEditorPatternFillContent()
    var alignsPatternWithCanvas = true
    var adaptsContentAwareColor = true
}

enum ImageEditorSelectionPatternAlignment {
    static func localizedContent(
        _ content: ImageEditorPatternFillContent,
        layerFrame: CGRect,
        alignsWithCanvas: Bool
    ) -> ImageEditorPatternFillContent {
        var localized = content.normalized()
        guard alignsWithCanvas else { return localized }
        let period = localized.scale
        localized.offsetX = (localized.offsetX - layerFrame.minX)
            .truncatingRemainder(dividingBy: period)
        localized.offsetY = (localized.offsetY - layerFrame.minY)
            .truncatingRemainder(dividingBy: period)
        return localized
    }
}

enum ImageEditorQuickMaskFillCompositor {
    static func fill(
        alpha: [UInt8],
        width: Int,
        targetAlpha: UInt8,
        opacity: CGFloat,
        blendMode: ImageEditorBlendMode
    ) -> [UInt8] {
        let normalizedOpacity = Double(max(0, min(1, opacity)))
        guard normalizedOpacity > 0, width > 0 else { return alpha }
        return alpha.enumerated().map { index, byte in
            blendedByte(
                baseByte: byte,
                targetAlpha: targetAlpha,
                sourceOpacity: normalizedOpacity,
                blendMode: blendMode,
                x: index % width,
                y: index / width
            )
        }
    }

    static func fill(
        alpha: [UInt8],
        width: Int,
        height: Int,
        targetAlpha: UInt8,
        pattern: ImageEditorPatternFillContent,
        opacity: CGFloat,
        blendMode: ImageEditorBlendMode
    ) -> [UInt8]? {
        guard width > 0, height > 0, alpha.count == width * height else { return nil }
        let image = pattern.normalized().renderedImage(
            size: CGSize(width: width, height: height)
        )
        guard let patternPixels = rgbaPixels(image: image, width: width, height: height) else {
            return nil
        }
        let normalizedOpacity = Double(max(0, min(1, opacity)))
        return alpha.enumerated().map { index, byte in
            let patternAlpha = Double(patternPixels[index * 4 + 3]) / 255
            return blendedByte(
                baseByte: byte,
                targetAlpha: targetAlpha,
                sourceOpacity: normalizedOpacity * patternAlpha,
                blendMode: blendMode,
                x: index % width,
                y: index / width
            )
        }
    }

    static func blendedByte(
        baseByte: UInt8,
        targetAlpha: UInt8,
        sourceOpacity: Double,
        blendMode: ImageEditorBlendMode,
        x: Int,
        y: Int
    ) -> UInt8 {
        guard sourceOpacity > 0 else { return baseByte }
        if blendMode == .dissolve {
            return dissolves(x: x, y: y, probability: sourceOpacity)
                ? targetAlpha
                : baseByte
        }
        let base = Double(baseByte) / 255
        let overlay = Double(targetAlpha) / 255
        let blended = blendMode.blend(
            baseRed: base,
            baseGreen: base,
            baseBlue: base,
            overlayRed: overlay,
            overlayGreen: overlay,
            overlayBlue: overlay
        ).red
        return byteValue(base * (1 - sourceOpacity) + blended * sourceOpacity)
    }

    private static func rgbaPixels(image: NSImage, width: Int, height: Int) -> [UInt8]? {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private static func byteValue(_ value: Double) -> UInt8 {
        UInt8((max(0, min(1, value)) * 255).rounded())
    }

    private static func dissolves(x: Int, y: Int, probability: Double) -> Bool {
        if probability >= 1 { return true }
        var value = UInt64(truncatingIfNeeded: x)
            &* 0x9E37_79B9_7F4A_7C15
            &+ UInt64(truncatingIfNeeded: y)
            &* 0xBF58_476D_1CE4_E5B9
            &+ 0x94D0_49BB_1331_11EB
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Double(value & 0xffff) / 65_535 < probability
    }
}

private struct ImageEditorPatchEditResult {
    let layerIndex: Int
    let image: NSImage
    let resultingSelection: ImageEditorSelection
}

private struct PatchTransparentTextureSampler {
    /// A compact local baseline separates sampled texture from its background
    /// color. The residual is then applied over the target instead of replacing
    /// it, matching the Patch tool's transparent-texture editing contract.
    static let textureRadius: CGFloat = 3
    private let pixels: [UInt8]
    private let localBaselinePixels: [UInt8]
    private let width: Int

    init(pixels: [UInt8], localBaselinePixels: [UInt8], width: Int) {
        self.pixels = pixels
        self.localBaselinePixels = localBaselinePixels
        self.width = width
    }

    func applyTexture(
        fromX sourceX: Int,
        sourceY: Int,
        to targetPixels: inout [UInt8],
        targetOffset: Int,
        maskAlpha: CGFloat
    ) {
        let sourceOffset = (sourceY * width + sourceX) * 4
        let sourceAlphaByte = Double(pixels[sourceOffset + 3])
        let targetAlphaByte = Double(targetPixels[targetOffset + 3])
        guard sourceAlphaByte > 0, targetAlphaByte > 0 else { return }

        let localAlphaByte = Double(localBaselinePixels[sourceOffset + 3])
        guard localAlphaByte > 0 else { return }
        let blendAlpha = Double(maskAlpha) * sourceAlphaByte / 255
        guard blendAlpha > 0 else { return }

        for channel in 0..<3 {
            let sourceStraight = Double(pixels[sourceOffset + channel]) / sourceAlphaByte
            let localMean = Double(localBaselinePixels[sourceOffset + channel]) / localAlphaByte
            let targetStraight = Double(targetPixels[targetOffset + channel]) / targetAlphaByte
            let texturedStraight = max(0, min(1, targetStraight + sourceStraight - localMean))
            let texturedPremultiplied = texturedStraight * targetAlphaByte
            let original = Double(targetPixels[targetOffset + channel])
            targetPixels[targetOffset + channel] = UInt8(max(
                0,
                min(255, (original * (1 - blendAlpha) + texturedPremultiplied * blendAlpha).rounded())
            ))
        }
    }
}

private enum ImageEditorSelectionCropMetrics {
    /// Core Image's Gaussian blur has a visible tail beyond the nominal
    /// radius. Three radii retain the feather while keeping clipboard and
    /// generated-layer bounds finite and predictable.
    static let gaussianFeatherExtentMultiplier: CGFloat = 3
}

@MainActor
extension ImageEditorViewModel {
    var effectiveHistoryFillSource: ImageEditorHistoryFillSource? {
        if let historyFillSource,
           historyFillDocument(for: historyFillSource) != nil {
            return historyFillSource
        }
        guard let firstEntry = document.history.first(where: { historySnapshots[$0.id] != nil }) else {
            return nil
        }
        return .entry(firstEntry.id)
    }

    var historyFillSourceTitle: String {
        guard let source = effectiveHistoryFillSource else {
            return L10n.text("imageEditor.selectionFill.historySourceUnavailable")
        }
        switch source {
        case .entry(let id):
            return document.history.first(where: { $0.id == id })?.title
                ?? L10n.text("imageEditor.selectionFill.historySourceUnavailable")
        case .snapshot(let id):
            return namedHistorySnapshots.first(where: { $0.id == id })?.name
                ?? L10n.text("imageEditor.selectionFill.historySourceUnavailable")
        }
    }

    var canFillSelectionFromHistory: Bool {
        !isQuickMaskMode
            && canEditSelectionPixels
            && effectiveHistoryFillSource != nil
    }

    func setHistoryFillSource(entryID: UUID) {
        guard document.history.contains(where: { $0.id == entryID }),
              historySnapshots[entryID] != nil
        else { return }
        historyFillSource = .entry(entryID)
        let title = document.history.first(where: { $0.id == entryID })?.title ?? ""
        statusText = L10n.format("imageEditor.status.historyFillSourceSet", title)
    }

    func setHistoryFillSource(snapshotID: UUID) {
        guard let snapshot = namedHistorySnapshots.first(where: { $0.id == snapshotID }) else { return }
        historyFillSource = .snapshot(snapshotID)
        statusText = L10n.format("imageEditor.status.historyFillSourceSet", snapshot.name)
    }

    func isHistoryFillSource(entryID: UUID) -> Bool {
        effectiveHistoryFillSource == .entry(entryID)
    }

    func isHistoryFillSource(snapshotID: UUID) -> Bool {
        effectiveHistoryFillSource == .snapshot(snapshotID)
    }

    var canEditSelectionPixels: Bool {
        hasPotentialSelectionPixels && !editableSelectionPixelLayerIndices().isEmpty
    }

    var canFillCurrentEditingTarget: Bool {
        isQuickMaskMode ? document.selection != nil : canEditSelectionPixels
    }

    var canRemoveSelectionPixels: Bool {
        hasPotentialSelectionPixels && !removableSelectionPixelLayerIndices().isEmpty
    }

    var canCopySelectionToNewLayer: Bool {
        guard selectedLayerCount == 1,
              let selection = document.selection,
              !isEditingLayerMask,
              let layer = document.selectedLayer
        else { return false }
        return !layer.isGroup
            && !layer.isAdjustment
            && !layer.isFilter
            && selection.mayAffect(
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                expansion: feather
            )
    }

    var canCutSelectionToNewLayer: Bool {
        canCopySelectionToNewLayer && canRemoveSelectionPixels
    }

    var canCopySelectionToClipboard: Bool {
        hasSelection
            ? canCopySelectionToNewLayer
            : canCopySelectedLayersToClipboard
    }

    var canCutSelectionToClipboard: Bool {
        if hasSelection {
            return canCopySelectionToClipboard && canCutSelectionToNewLayer
        }
        return canCutSelectedLayersToClipboard
    }

    var canCutSelectedLayersToClipboard: Bool {
        canCutLayerSelectionToClipboard(document.selectedLayerIDs)
    }

    var canCopyMergedToClipboard: Bool {
        document.canvasSize.width > 0 && document.canvasSize.height > 0
    }

    var canCopySelectedLayersToClipboard: Bool {
        canCopyLayerSelectionToClipboard(document.selectedLayerIDs)
    }

    var canCopyMergedToNewLayer: Bool {
        canCopyMergedToClipboard
    }

    var canDuplicateSelectionOrSelectedLayer: Bool {
        canCopySelectionToNewLayer || canDuplicateSelectedLayer
    }

    private var hasPotentialSelectionPixels: Bool {
        guard let selection = document.selection else { return false }
        return selection.mayAffect(
            layerFrame: CGRect(origin: .zero, size: document.canvasSize),
            canvasSize: document.canvasSize
        )
    }

    func duplicateSelectionOrSelectedLayer() {
        if canCopySelectionToNewLayer {
            copySelectionToNewLayer()
        } else {
            duplicateSelectedLayer()
        }
    }

    func fillSelection() {
        fillSelection(with: foregroundColor, opacity: opacity)
    }

    func fillSelectionPreservingTransparency() {
        fillSelection(with: foregroundColor, opacity: opacity, preservingTransparency: true)
    }

    func fillSelectionWithBackgroundColor() {
        fillSelection(with: backgroundColor, opacity: opacity)
    }

    func fillSelectionWithBackgroundColorPreservingTransparency() {
        fillSelection(with: backgroundColor, opacity: opacity, preservingTransparency: true)
    }

    func fillSelectionFromHistoryPreservingTransparency() {
        fillSelectionFromHistory(
            opacity: 1,
            blendMode: .normal,
            preservingTransparency: true
        )
    }

    func presentSelectionFillPanel() {
        guard canFillCurrentEditingTarget else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        selectionFillContents = .foreground
        selectionFillCustomColor = foregroundColor
        selectionFillBlendMode = .normal
        selectionFillOpacity = 1
        selectionFillPreservesTransparency = false
        isSelectionFillSheetPresented = true
    }

    func applySelectionFillFromPanel() {
        let options = ImageEditorSelectionFillOptions(
            contents: selectionFillContents,
            customColor: selectionFillCustomColor,
            blendMode: selectionFillBlendMode,
            opacity: selectionFillOpacity,
            preservesTransparency: selectionFillPreservesTransparency,
            patternContent: selectionFillPatternContent,
            alignsPatternWithCanvas: selectionFillPatternAlignsWithCanvas,
            adaptsContentAwareColor: selectionFillContentAwareColorAdaptation
        )
        isSelectionFillSheetPresented = false
        fillSelection(options: options)
    }

    func fillSelection(options: ImageEditorSelectionFillOptions) {
        if options.contents == .history {
            guard !isQuickMaskMode else {
                statusText = L10n.text("imageEditor.status.operationFailed")
                return
            }
            fillSelectionFromHistory(
                opacity: options.opacity,
                blendMode: options.blendMode,
                preservingTransparency: options.preservesTransparency
            )
            return
        }
        if options.contents == .contentAware {
            guard !isQuickMaskMode else {
                statusText = L10n.text("imageEditor.status.operationFailed")
                return
            }
            contentAwareFillSelection(
                opacity: options.opacity,
                blendMode: options.blendMode,
                preservingTransparency: options.preservesTransparency,
                colorAdaptation: options.adaptsContentAwareColor
            )
            return
        }
        if options.contents == .pattern {
            fillSelection(
                with: options.patternContent,
                opacity: options.opacity,
                blendMode: options.blendMode,
                preservingTransparency: options.preservesTransparency,
                alignsWithCanvas: options.alignsPatternWithCanvas
            )
            return
        }
        guard let color = options.contents.resolvedColor(
            foreground: foregroundColor,
            background: backgroundColor,
            custom: options.customColor
        ) else { return }
        fillSelection(
            with: color,
            opacity: options.opacity,
            blendMode: options.blendMode,
            preservingTransparency: options.preservesTransparency
        )
    }

    func fillSelectionFromHistory() {
        fillSelectionFromHistory(
            opacity: 1,
            blendMode: .normal,
            preservingTransparency: false
        )
    }

    @discardableResult
    func historyBrush(samples: [ImageEditorBrushStrokeSample]) -> Bool {
        historyBrush(samples: samples, blendMode: historyBrushBlendMode)
    }

    @discardableResult
    private func historyBrush(
        samples: [ImageEditorBrushStrokeSample],
        blendMode: ImageEditorBlendMode
    ) -> Bool {
        guard !samples.isEmpty else { return false }
        guard !isQuickMaskMode, !isEditingLayerMask else {
            statusText = L10n.text("imageEditor.status.historyBrushUnavailable")
            return false
        }
        guard let index = document.selectedLayerIndex else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return false
        }
        let layer = document.layers[index]
        guard layer.kind.isPixel,
              !document.isEffectivelyPixelsLocked(layer)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }
        guard let source = effectiveHistoryFillSource,
              let sourceDocument = historyFillDocument(for: source),
              let sourceLayer = sourceDocument.layers.first(where: {
                  $0.id == layer.id && $0.kind.isPixel
              })
        else {
            statusText = L10n.text("imageEditor.status.historyFillSourceUnavailable")
            return false
        }

        let scaleX = layer.image.size.width / max(layer.frame.width, 1)
        let scaleY = layer.image.size.height / max(layer.frame.height, 1)
        let localSamples = samples.map { sample in
            ImageEditorBrushStrokeSample(
                point: CGPoint(
                    x: (sample.point.x - layer.frame.minX) * scaleX,
                    y: (sample.point.y - layer.frame.minY) * scaleY
                ),
                pressure: sample.pressure,
                tilt: sample.tilt
            )
        }
        let output = layer.image.historyBrushed(
            from: sourceLayer.image,
            sourceLayerFrame: sourceLayer.frame,
            layerFrame: layer.frame,
            samples: localSamples,
            settings: ImageEditorBrushStrokeSettings(
                diameter: brushSize * sqrt(max(0.0001, scaleX * scaleY)),
                hardness: hardness,
                opacity: opacity,
                flow: brushFlow / 100,
                spacing: brushSpacing / 100,
                pressureControlsSize: brushPressureControlsSize,
                pressureControlsOpacity: brushPressureControlsOpacity,
                pressureControlsFlow: brushPressureControlsFlow,
                pressureSensitivity: brushPressureSensitivity / 100,
                minimumDiameter: brushMinimumDiameter / 100,
                minimumOpacity: brushMinimumOpacity / 100,
                minimumFlow: brushMinimumFlow / 100,
                tiltControlsShape: brushTiltControlsShape,
                tipRoundness: brushTipRoundness / 100,
                tipAngleDegrees: brushTipAngleDegrees,
                smoothing: brushSmoothing / 100
            ),
            blendMode: blendMode
        )
        guard let output else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return false
        }
        let didChange = replaceSelectedLayerRenderedPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.historyBrush"),
            resetFrame: false,
            skipIfUnchanged: true,
            unchangedStatusKey: "imageEditor.status.historyBrushUnchanged"
        )
        if didChange {
            statusText = L10n.text("imageEditor.status.historyBrushApplied")
        }
        return didChange
    }

    var canEraseToHistory: Bool {
        guard !isQuickMaskMode,
              !isEditingLayerMask,
              let index = document.selectedLayerIndex
        else { return false }
        let layer = document.layers[index]
        guard layer.kind.isPixel,
              !document.isEffectivelyPixelsLocked(layer),
              let source = effectiveHistoryFillSource,
              let sourceDocument = historyFillDocument(for: source)
        else { return false }
        return sourceDocument.layers.contains {
            $0.id == layer.id && $0.kind.isPixel
        }
    }

    func shouldEraseToHistory(modifierFlags: NSEvent.ModifierFlags) -> Bool {
        canEraseToHistory
            && (eraserErasesToHistory || modifierFlags.contains(.option))
    }

    func eraseBrush(
        samples: [ImageEditorBrushStrokeSample],
        restoringHistory: Bool
    ) {
        if restoringHistory {
            _ = historyBrush(samples: samples, blendMode: .normal)
        } else {
            drawBrush(samples: samples, erase: true)
        }
    }

    private func fillSelectionFromHistory(
        opacity: CGFloat,
        blendMode: ImageEditorBlendMode,
        preservingTransparency: Bool
    ) {
        guard !isQuickMaskMode else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard let source = effectiveHistoryFillSource,
              let sourceDocument = historyFillDocument(for: source)
        else {
            statusText = L10n.text("imageEditor.status.historyFillSourceUnavailable")
            return
        }
        let editableIndices = editableSelectionPixelLayerIndices()
        guard !editableIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard editableIndices.contains(where: { index in
            let layer = document.layers[index]
            return sourceDocument.layers.contains(where: { $0.id == layer.id && $0.kind.isPixel })
                && selection.mayAffect(
                    layerFrame: layer.frame,
                    canvasSize: document.canvasSize,
                    expansion: feather
                )
        }) else {
            statusText = L10n.text("imageEditor.status.historyFillSourceUnavailable")
            return
        }

        applySelectionPixelEdit(
            historyKey: "imageEditor.history.selectionHistoryFill",
            selectedHistoryKey: "imageEditor.history.selectionHistoryFillSelected",
            statusKey: "imageEditor.status.selectionHistoryFilled",
            selectedStatusKey: "imageEditor.status.selectionHistoryFilledSelected",
            noChangeStatusKey: "imageEditor.status.historyFillUnchanged"
        ) { layer in
            guard selection.mayAffect(
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                expansion: feather
            ),
            let sourceLayer = sourceDocument.layers.first(where: { $0.id == layer.id && $0.kind.isPixel }),
            let output = layer.image.historyFilled(
                from: sourceLayer.image,
                sourceLayerFrame: sourceLayer.frame,
                selection: selection,
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                opacity: opacity,
                blendMode: blendMode,
                feather: feather
            ) else { return nil }
            return preservingTransparency || document.isEffectivelyTransparencyLocked(layer)
                ? (output.preservingAlpha(from: layer.image) ?? output)
                : output
        }
    }

    private func historyFillDocument(for source: ImageEditorHistoryFillSource) -> ImageEditorDocument? {
        switch source {
        case .entry(let id):
            guard document.history.contains(where: { $0.id == id }) else { return nil }
            return historySnapshots[id]
        case .snapshot(let id):
            return namedHistorySnapshots.first(where: { $0.id == id })?.document
        }
    }

    private func fillSelection(
        with pattern: ImageEditorPatternFillContent,
        opacity: CGFloat,
        blendMode: ImageEditorBlendMode,
        preservingTransparency: Bool,
        alignsWithCanvas: Bool
    ) {
        if isQuickMaskMode {
            fillQuickMask(
                with: pattern,
                opacity: opacity,
                blendMode: blendMode
            )
            return
        }
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        let editableIndices = editableSelectionPixelLayerIndices()
        guard !editableIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard editableIndices.contains(where: { index in
            selection.mayAffect(
                layerFrame: document.layers[index].frame,
                canvasSize: document.canvasSize,
                expansion: feather
            )
        }) else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return
        }
        applySelectionPixelEdit(
            historyKey: "imageEditor.history.selectionFill",
            selectedHistoryKey: "imageEditor.history.selectionFillSelected",
            statusKey: "imageEditor.status.selectionFilled",
            selectedStatusKey: "imageEditor.status.selectionFilledSelected"
        ) { layer in
            guard selection.mayAffect(
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                expansion: feather
            ) else { return nil }
            guard let output = layer.image.filled(
                selection: selection,
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                pattern: pattern,
                alignsWithCanvas: alignsWithCanvas,
                opacity: opacity,
                blendMode: blendMode,
                feather: feather
            ) else { return nil }
            return preservingTransparency || document.isEffectivelyTransparencyLocked(layer)
                ? (output.preservingAlpha(from: layer.image) ?? output)
                : output
        }
    }

    private func fillSelection(
        with color: NSColor,
        opacity: CGFloat,
        blendMode: ImageEditorBlendMode = .normal,
        preservingTransparency: Bool = false
    ) {
        if isQuickMaskMode {
            fillQuickMask(with: color, opacity: opacity, blendMode: blendMode)
            return
        }
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        let editableIndices = editableSelectionPixelLayerIndices()
        guard !editableIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard editableIndices.contains(where: { index in
            selection.mayAffect(
                layerFrame: document.layers[index].frame,
                canvasSize: document.canvasSize,
                expansion: feather
            )
        }) else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return
        }
        applySelectionPixelEdit(
            historyKey: "imageEditor.history.selectionFill",
            selectedHistoryKey: "imageEditor.history.selectionFillSelected",
            statusKey: "imageEditor.status.selectionFilled",
            selectedStatusKey: "imageEditor.status.selectionFilledSelected"
        ) { layer in
            guard selection.mayAffect(
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                expansion: feather
            ) else { return nil }
            guard let output = layer.image.filled(
                selection: selection,
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                color: color,
                opacity: opacity,
                blendMode: blendMode,
                feather: feather
            ) else { return nil }
            return preservingTransparency || document.isEffectivelyTransparencyLocked(layer)
                ? (output.preservingAlpha(from: layer.image) ?? output)
                : output
        }
    }

    func strokeSelection() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        let strokeExpansion = max(1, brushSize) / 2 + max(0, feather)
        let editableIndices = editableSelectionPixelLayerIndices()
        guard !editableIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard editableIndices.contains(where: { index in
            selection.mayAffect(
                layerFrame: document.layers[index].frame,
                canvasSize: document.canvasSize,
                expansion: strokeExpansion
            )
        }) else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return
        }
        applySelectionPixelEdit(
            historyKey: "imageEditor.history.selectionStroke",
            selectedHistoryKey: "imageEditor.history.selectionStrokeSelected",
            statusKey: "imageEditor.status.selectionStroked",
            selectedStatusKey: "imageEditor.status.selectionStrokedSelected"
        ) { layer in
            guard selection.mayAffect(
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                expansion: strokeExpansion
            ) else { return nil }
            guard let output = layer.image.stroked(
                selection: selection,
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                color: foregroundColor,
                width: max(1, brushSize),
                opacity: opacity,
                feather: feather
            ) else { return nil }
            return document.isEffectivelyTransparencyLocked(layer)
                ? (output.preservingAlpha(from: layer.image) ?? output)
                : output
        }
    }

    func contentAwareFillSelection() {
        contentAwareFillSelection(
            opacity: 1,
            blendMode: .normal,
            preservingTransparency: false,
            colorAdaptation: true
        )
    }

    private func contentAwareFillSelection(
        opacity: CGFloat,
        blendMode: ImageEditorBlendMode,
        preservingTransparency: Bool,
        colorAdaptation: Bool
    ) {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        let editableIndices = editableSelectionPixelLayerIndices()
        guard !editableIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard editableIndices.contains(where: { index in
            selection.mayAffect(
                layerFrame: document.layers[index].frame,
                canvasSize: document.canvasSize,
                expansion: feather
            )
        }) else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return
        }
        applySelectionPixelEdit(
            historyKey: "imageEditor.history.selectionContentAwareFill",
            selectedHistoryKey: "imageEditor.history.selectionContentAwareFillSelected",
            statusKey: "imageEditor.status.selectionContentAwareFilled",
            selectedStatusKey: "imageEditor.status.selectionContentAwareFilledSelected"
        ) { layer in
            guard selection.mayAffect(
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                expansion: feather
            ) else { return nil }
            guard let output = layer.image.contentAwareFilled(
                selection: selection,
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                opacity: opacity,
                blendMode: blendMode,
                colorAdaptation: colorAdaptation,
                feather: feather
            ) else { return nil }
            return preservingTransparency || document.isEffectivelyTransparencyLocked(layer)
                ? (output.preservingAlpha(from: layer.image) ?? output)
                : output
        }
    }

    func createPatchSelection(points: [CGPoint]) {
        let previousSelection = document.selection
        createLassoSelection(points: points)
        if document.selection != previousSelection, document.selection != nil {
            statusText = L10n.text("imageEditor.status.patchSelectionReady")
        }
    }

    func canBeginPatch(at point: CGPoint?) -> Bool {
        guard let point, let selection = document.selection else { return false }
        return selection.contains(point, canvasSize: document.canvasSize)
    }

    func patchPreviewImage(from start: CGPoint?, to end: CGPoint?) -> NSImage? {
        guard let result = patchEditResult(from: start, to: end) else { return nil }
        var previewDocument = document
        previewDocument.layers[result.layerIndex].image = result.image
        return previewDocument.compositedImage
    }

    func patchSelection(from start: CGPoint?, to end: CGPoint?) {
        guard document.selection != nil else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard let start, let end,
              hypot(end.x - start.x, end.y - start.y) >= 1
        else { return }
        guard let result = patchEditResult(from: start, to: end) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[result.layerIndex].image = result.image
        document.selection = result.resultingSelection
        appendHistory(L10n.text("imageEditor.history.selectionPatch"))
        statusText = L10n.text(
            patchMode == .source
                ? "imageEditor.status.selectionPatchedSource"
                : "imageEditor.status.selectionPatchedDestination"
        )
    }

    private func patchEditResult(
        from start: CGPoint?,
        to end: CGPoint?
    ) -> ImageEditorPatchEditResult? {
        guard let selection = document.selection,
              let start,
              let end,
              canEditSelectionPixels,
              let index = document.selectedLayerIndex
        else { return nil }
        let dragOffset = CGSize(width: end.x - start.x, height: end.y - start.y)
        guard hypot(dragOffset.width, dragOffset.height) >= 1 else { return nil }

        let targetSelection: ImageEditorSelection
        let sampleOffset: CGSize
        switch patchMode {
        case .source:
            targetSelection = selection
            sampleOffset = dragOffset
        case .destination:
            guard let translated = selection.patchTranslated(
                by: dragOffset,
                canvasSize: document.canvasSize
            ) else { return nil }
            targetSelection = translated
            sampleOffset = CGSize(width: -dragOffset.width, height: -dragOffset.height)
        }

        let layer = document.layers[index]
        let samplingImage: NSImage?
        if patchSampleSource != .currentLayer {
            guard let sampledInput = sampledBrushInput(
                for: layer,
                canvasOffset: .zero,
                sampleSource: patchSampleSource,
                ignoringAdjustmentLayers: patchIgnoresAdjustmentLayers
            ) else { return nil }
            samplingImage = sampledInput.image
        } else {
            samplingImage = nil
        }
        guard let output = layer.image.patched(
            selection: targetSelection,
            layerFrame: layer.frame,
            canvasSize: document.canvasSize,
            offsetInCanvas: sampleOffset,
            opacity: opacity,
            feather: feather,
            extractsTextureTransparently: patchTransparentEnabled,
            diffusion: patchDiffusion,
            samplingImage: samplingImage
        ) else { return nil }
        let protectedOutput = document.isEffectivelyTransparencyLocked(layer)
            ? (output.preservingAlpha(from: layer.image) ?? output)
            : output
        return ImageEditorPatchEditResult(
            layerIndex: index,
            image: protectedOutput.normalizedBitmapImage(),
            resultingSelection: targetSelection
        )
    }

    func copySelectionToNewLayer() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard canCopySelectionToNewLayer else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let index = document.selectedLayerIndex,
              let clippedImage = document.layers[index].visibleImage.copied(
                selection: selection,
                layerFrame: document.layers[index].frame,
                canvasSize: document.canvasSize,
                feather: feather
              ),
              let selectionCopy = selectionClipboardCopy(
                clippedImage: clippedImage,
                selection: selection,
                layerFrame: document.layers[index].frame,
                feather: feather
              )
        else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return
        }

        pushUndo()
        let sourceLayer = document.layers[index]
        var layer = ImageEditorLayer.blank(
            name: L10n.format("imageEditor.layer.selectionCopyName", sourceLayer.name),
            size: selectionCopy.image.size
        )
        layer.image = selectionCopy.image
        layer.frame = selectionCopy.frame
        layer.isVisible = sourceLayer.isVisible
        layer.opacity = sourceLayer.opacity
        layer.fillOpacity = sourceLayer.fillOpacity
        layer.blendMode = sourceLayer.blendMode
        layer.blendIfSourceBlack = sourceLayer.blendIfSourceBlack
        layer.blendIfSourceWhite = sourceLayer.blendIfSourceWhite
        layer.blendIfUnderlyingBlack = sourceLayer.blendIfUnderlyingBlack
        layer.blendIfUnderlyingWhite = sourceLayer.blendIfUnderlyingWhite
        layer.style = sourceLayer.style
        layer.groupID = sourceLayer.groupID
        layer.stackChildLayout = sourceLayer.stackChildLayout
        layer.isStackLayoutExcluded = sourceLayer.isStackLayoutExcluded
        layer.isClippingMask = sourceLayer.isClippingMask
        layer.labelColor = sourceLayer.labelColor
        document.layers.insert(layer, at: index + 1)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.selectionCopyLayer"))
        statusText = L10n.text("imageEditor.status.selectionCopiedToLayer")
    }

    func clearSelectionPixels() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        let editableIndices = removableSelectionPixelLayerIndices()
        guard !editableIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard editableIndices.contains(where: { index in
            selection.mayAffect(
                layerFrame: document.layers[index].frame,
                canvasSize: document.canvasSize,
                expansion: feather
            )
        }) else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return
        }
        applySelectionPixelEdit(
            historyKey: "imageEditor.history.selectionClearPixels",
            selectedHistoryKey: "imageEditor.history.selectionClearPixelsSelected",
            statusKey: "imageEditor.status.selectionPixelsCleared",
            selectedStatusKey: "imageEditor.status.selectionPixelsClearedSelected"
        ) { layer in
            guard !document.isEffectivelyTransparencyLocked(layer) else { return nil }
            guard selection.mayAffect(
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                expansion: feather
            ) else { return nil }
            return layer.image.cleared(
                selection: selection,
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                feather: feather
            )
        }
    }

    func cutSelectionToNewLayer() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard canCutSelectionToNewLayer else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let index = document.selectedLayerIndex,
              let clippedImage = document.layers[index].visibleImage.copied(
                selection: selection,
                layerFrame: document.layers[index].frame,
                canvasSize: document.canvasSize,
                feather: feather
              ),
              let selectionCopy = selectionClipboardCopy(
                clippedImage: clippedImage,
                selection: selection,
                layerFrame: document.layers[index].frame,
                feather: feather
              ),
              let clearedImage = document.layers[index].image.cleared(
                selection: selection,
                layerFrame: document.layers[index].frame,
                canvasSize: document.canvasSize,
                feather: feather
              )
        else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return
        }

        pushUndo()
        document.layers[index].image = clearedImage.normalizedBitmapImage()
        let sourceLayer = document.layers[index]
        var layer = ImageEditorLayer.blank(
            name: L10n.format("imageEditor.layer.selectionCutName", sourceLayer.name),
            size: selectionCopy.image.size
        )
        layer.image = selectionCopy.image
        layer.frame = selectionCopy.frame
        layer.isVisible = sourceLayer.isVisible
        layer.opacity = sourceLayer.opacity
        layer.fillOpacity = sourceLayer.fillOpacity
        layer.blendMode = sourceLayer.blendMode
        layer.blendIfSourceBlack = sourceLayer.blendIfSourceBlack
        layer.blendIfSourceWhite = sourceLayer.blendIfSourceWhite
        layer.blendIfUnderlyingBlack = sourceLayer.blendIfUnderlyingBlack
        layer.blendIfUnderlyingWhite = sourceLayer.blendIfUnderlyingWhite
        layer.style = sourceLayer.style
        layer.groupID = sourceLayer.groupID
        layer.stackChildLayout = sourceLayer.stackChildLayout
        layer.isStackLayoutExcluded = sourceLayer.isStackLayoutExcluded
        layer.isClippingMask = sourceLayer.isClippingMask
        layer.labelColor = sourceLayer.labelColor
        document.layers.insert(layer, at: index + 1)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.selectionCutLayer"))
        statusText = L10n.text("imageEditor.status.selectionCutToLayer")
    }

    @discardableResult
    func copySelectionToClipboard() -> Bool {
        guard hasSelection else {
            return copySelectedLayersToClipboard()
        }

        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return false
        }
        guard canCopySelectionToClipboard else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return false
        }
        guard let layer = document.selectedLayer,
              let clippedImage = layer.visibleImage.copied(
                selection: selection,
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                feather: feather
              ),
              let clipboardCopy = selectionClipboardCopy(
                clippedImage: clippedImage,
                selection: selection,
                layerFrame: layer.frame,
                feather: feather
              )
        else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return false
        }

        let didCopy = ClipboardImageWriter.copy(
            clipboardCopy.image,
            preferredFileName: "\(layer.name)-selection.png"
        )
        if didCopy {
            XomoClipboardLayerPayload.write(frame: clipboardCopy.frame)
        }
        statusText = didCopy
            ? L10n.text("imageEditor.status.selectionCopiedToClipboard")
            : L10n.text("imageEditor.status.selectionCopyToClipboardFailed")
        return didCopy
    }

    private func selectionClipboardCopy(
        clippedImage: NSImage,
        selection: ImageEditorSelection,
        layerFrame: CGRect,
        feather: CGFloat
    ) -> (image: NSImage, frame: CGRect)? {
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        let featherExtent = ceil(
            max(0, feather)
                * ImageEditorSelectionCropMetrics.gaussianFeatherExtentMultiplier
        )
        let appKitLayerFrame = CGRect(
            x: layerFrame.minX,
            y: document.canvasSize.height - layerFrame.maxY,
            width: layerFrame.width,
            height: layerFrame.height
        )
        guard let canvasImage = NSImage.rendered(size: document.canvasSize, actions: { _ in
            clippedImage.draw(
                in: appKitLayerFrame,
                from: CGRect(origin: .zero, size: clippedImage.size),
                operation: .copy,
                fraction: 1
            )
        }), let contentBounds = canvasImage.nonTransparentPixelBounds() else { return nil }

        guard let selectedBounds = selection.effectiveSelectedBounds(
            in: document.canvasSize
        ) else { return nil }
        let candidateFrame = selection.isInverted
            ? contentBounds.integral
            : selectedBounds.standardized
                .insetBy(dx: -featherExtent, dy: -featherExtent)
                .integral
        let clipboardFrame = candidateFrame.intersection(canvasBounds)
        guard !clipboardFrame.isNull,
              !clipboardFrame.isEmpty,
              let croppedImage = canvasImage.croppedUsingImagePixelCoordinates(to: clipboardFrame),
              croppedImage.nonTransparentPixelBounds() != nil
        else { return nil }

        return (croppedImage.normalizedBitmapImage(), clipboardFrame)
    }

    @discardableResult
    func cutSelectionToClipboard() -> Bool {
        guard hasSelection else {
            return cutSelectedLayersToClipboard()
        }

        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return false
        }
        guard canCutSelectionToClipboard else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return false
        }
        guard let index = document.selectedLayerIndex,
              let clippedImage = document.layers[index].visibleImage.copied(
                selection: selection,
                layerFrame: document.layers[index].frame,
                canvasSize: document.canvasSize,
                feather: feather
              ),
              let clipboardCopy = selectionClipboardCopy(
                clippedImage: clippedImage,
                selection: selection,
                layerFrame: document.layers[index].frame,
                feather: feather
              )
        else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return false
        }

        let sourceLayer = document.layers[index]
        let didCopy = ClipboardImageWriter.copy(
            clipboardCopy.image,
            preferredFileName: "\(sourceLayer.name)-selection.png"
        )
        guard didCopy,
              let output = sourceLayer.image.cleared(
                selection: selection,
                layerFrame: sourceLayer.frame,
                canvasSize: document.canvasSize,
                feather: feather
              )
        else {
            statusText = L10n.text("imageEditor.status.selectionCopyToClipboardFailed")
            return false
        }

        XomoClipboardLayerPayload.write(frame: clipboardCopy.frame)
        pushUndo()
        document.layers[index].image = output.normalizedBitmapImage()
        appendHistory(L10n.text("imageEditor.history.selectionCutClipboard"))
        statusText = L10n.text("imageEditor.status.selectionCutToClipboard")
        return true
    }

    @discardableResult
    func cutSelectedLayersToClipboard(
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        guard canCutSelectedLayersToClipboard else {
            statusText = L10n.text("imageEditor.status.selectedLayerCutToClipboardFailed")
            return false
        }
        guard copySelectedLayersToClipboard(to: pasteboard) else { return false }
        guard deleteSelectedLayer(
            historyTitle: L10n.text("imageEditor.history.selectedLayerCutToClipboard")
        ) else {
            statusText = L10n.text("imageEditor.status.selectedLayerCutToClipboardFailed")
            return false
        }
        statusText = L10n.text("imageEditor.status.selectedLayerCutToClipboard")
        return true
    }

    @discardableResult
    func copyMergedToClipboard() -> Bool {
        guard canCopyMergedToClipboard else {
            statusText = L10n.text("imageEditor.status.copyMergedToClipboardFailed")
            return false
        }

        let clipboardCopy: (image: NSImage, frame: CGRect)
        if let selection = document.selection {
            guard let clippedImage = document.compositedImage.copied(
                selection: selection,
                layerFrame: CGRect(origin: .zero, size: document.canvasSize),
                canvasSize: document.canvasSize,
                feather: feather
            ), let selectionCopy = selectionClipboardCopy(
                clippedImage: clippedImage,
                selection: selection,
                layerFrame: CGRect(origin: .zero, size: document.canvasSize),
                feather: feather
            ) else {
                statusText = L10n.text("imageEditor.status.selectionEmpty")
                return false
            }
            clipboardCopy = selectionCopy
        } else {
            clipboardCopy = (
                document.compositedImage.normalizedBitmapImage(),
                CGRect(origin: .zero, size: document.canvasSize)
            )
        }

        let didCopy = ClipboardImageWriter.copy(
            clipboardCopy.image,
            preferredFileName: "\(document.sourceName)-merged.png"
        )
        if didCopy {
            XomoClipboardLayerPayload.write(frame: clipboardCopy.frame)
        }
        statusText = didCopy
            ? L10n.text("imageEditor.status.copyMergedToClipboard")
            : L10n.text("imageEditor.status.copyMergedToClipboardFailed")
        return didCopy
    }

    @discardableResult
    func copySelectedLayersToClipboard(
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        guard canCopySelectedLayersToClipboard,
              let archiveData = XomoLayerClipboardArchive.data(
                  layers: document.layers,
                  selectedIDs: document.selectedLayerIDs,
                  primarySelectionID: document.selectedLayerID
              )
        else {
            statusText = L10n.text("imageEditor.status.selectedLayersCopyToClipboardFailed")
            return false
        }

        let renderedImage = document.compositedImage(
            includingOnly: document.selectedLayerIDs
        )
        let bitmapContentBounds = renderedImage.nonTransparentPixelBounds()
        let image = bitmapContentBounds.flatMap {
            renderedImage.croppedUsingImagePixelCoordinates(to: $0)
        }
        let clipboardData = image?.qingtuPNGData()
        var additionalData = [XomoLayerClipboardArchive.pasteboardType: archiveData]
        if let bitmapContentBounds,
           let frameData = XomoClipboardLayerPayload.data(for: bitmapContentBounds) {
            additionalData[XomoClipboardLayerPayload.pasteboardType] = frameData
        }

        let baseName = (document.sourceName as NSString).deletingPathExtension
        let preferredFileName = "\(baseName.isEmpty ? "image" : baseName)-selected-layers.png"
        let didCopy = ClipboardImageWriter.copyPNGData(
            clipboardData,
            image: image,
            preferredFileName: preferredFileName,
            additionalData: additionalData,
            to: pasteboard
        )
        statusText = didCopy
            ? L10n.text("imageEditor.status.selectedLayersCopiedToClipboard")
            : L10n.text("imageEditor.status.selectedLayersCopyToClipboardFailed")
        return didCopy
    }

    func copyMergedToNewLayer() {
        guard canCopyMergedToNewLayer else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let mergedCopy: (image: NSImage, frame: CGRect)
        let layerNameKey: String
        if let selection = document.selection {
            guard let clippedImage = document.compositedImage.copied(
                selection: selection,
                layerFrame: CGRect(origin: .zero, size: document.canvasSize),
                canvasSize: document.canvasSize,
                feather: feather
            ), let selectionCopy = selectionClipboardCopy(
                clippedImage: clippedImage,
                selection: selection,
                layerFrame: CGRect(origin: .zero, size: document.canvasSize),
                feather: feather
            ) else {
                statusText = L10n.text("imageEditor.status.selectionEmpty")
                return
            }
            mergedCopy = selectionCopy
            layerNameKey = "imageEditor.layer.mergedSelectionCopyName"
        } else {
            mergedCopy = (
                document.compositedImage.normalizedBitmapImage(),
                CGRect(origin: .zero, size: document.canvasSize)
            )
            layerNameKey = "imageEditor.layer.mergedCopyName"
        }

        pushUndo()
        var layer = ImageEditorLayer.blank(
            name: L10n.text(layerNameKey),
            size: mergedCopy.image.size
        )
        layer.image = mergedCopy.image
        layer.frame = mergedCopy.frame
        layer.opacity = 1
        layer.fillOpacity = 1
        layer.blendMode = .normal
        layer.groupID = nil
        layer.isClippingMask = false
        document.layers.append(layer)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.selectionCopyMergedLayer"))
        statusText = L10n.text("imageEditor.status.selectionCopiedMergedToLayer")
    }

    private func editableSelectionPixelLayerIndices() -> [Int] {
        guard hasSelection, !isEditingLayerMask else { return [] }
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && layer.kind.isPixel
                && !document.isEffectivelyPixelsLocked(layer)
        }
    }

    private func removableSelectionPixelLayerIndices() -> [Int] {
        editableSelectionPixelLayerIndices().filter { index in
            !document.isEffectivelyTransparencyLocked(document.layers[index])
        }
    }

    private func applySelectionPixelEdit(
        historyKey: String,
        selectedHistoryKey: String,
        statusKey: String,
        selectedStatusKey: String,
        noChangeStatusKey: String = "imageEditor.status.selectionEmpty",
        render: (ImageEditorLayer) -> NSImage?
    ) {
        let edits = editableSelectionPixelLayerIndices().compactMap { index -> (Int, NSImage)? in
            let source = document.layers[index].image.normalizedBitmapImage()
            guard let output = render(document.layers[index])?.normalizedBitmapImage() else { return nil }
            if let outputData = output.qingtuPNGData(),
               let sourceData = source.qingtuPNGData(),
               outputData == sourceData {
                return nil
            }
            return (index, output)
        }
        guard !edits.isEmpty else {
            statusText = L10n.text(noChangeStatusKey)
            return
        }

        pushUndo()
        for (index, image) in edits {
            document.layers[index].image = image
        }
        appendHistory(L10n.text(edits.count == 1 ? historyKey : selectedHistoryKey))
        statusText = edits.count == 1
            ? L10n.text(statusKey)
            : L10n.format(selectedStatusKey, edits.count)
    }
}

extension NSImage {
    /// `nonTransparentPixelBounds()` scans rows in the CGImage's native pixel
    /// order. Crop that same CGImage directly so AppKit's bottom-left drawing
    /// coordinates cannot mirror the requested transparent-content bounds.
    func croppedUsingImagePixelCoordinates(to bounds: CGRect) -> NSImage? {
        guard let source = cgImage(forProposedRect: nil, context: nil, hints: nil),
              size.width > 0,
              size.height > 0
        else { return nil }

        let scaleX = CGFloat(source.width) / size.width
        let scaleY = CGFloat(source.height) / size.height
        let pixelBounds = CGRect(
            x: bounds.minX * scaleX,
            y: bounds.minY * scaleY,
            width: bounds.width * scaleX,
            height: bounds.height * scaleY
        ).integral.intersection(CGRect(x: 0, y: 0, width: source.width, height: source.height))
        guard pixelBounds.width > 0,
              pixelBounds.height > 0,
              let cropped = source.cropping(to: pixelBounds)
        else { return nil }

        return NSImage(
            cgImage: cropped,
            size: NSSize(width: pixelBounds.width / scaleX, height: pixelBounds.height / scaleY)
        )
    }
}

private extension NSImage {
    func filled(
        selection: ImageEditorSelection,
        layerFrame: CGRect,
        canvasSize: CGSize,
        color: NSColor,
        opacity: CGFloat,
        blendMode: ImageEditorBlendMode,
        feather: CGFloat
    ) -> NSImage? {
        guard let selectionMask = selection.layerMask(
            layerFrame: layerFrame,
            layerSize: size,
            canvasSize: canvasSize,
            feather: feather
        ) else { return nil }

        guard let fillColor = color.usingColorSpace(.deviceRGB) else { return nil }
        let overlay = (
            red: Double(fillColor.redComponent),
            green: Double(fillColor.greenComponent),
            blue: Double(fillColor.blueComponent),
            alpha: Double(fillColor.alphaComponent)
        )
        return compositedSelectionFill(
            selectionMask: selectionMask,
            opacity: opacity,
            blendMode: blendMode
        ) { _ in overlay }
    }

    func filled(
        selection: ImageEditorSelection,
        layerFrame: CGRect,
        canvasSize: CGSize,
        pattern: ImageEditorPatternFillContent,
        alignsWithCanvas: Bool,
        opacity: CGFloat,
        blendMode: ImageEditorBlendMode,
        feather: CGFloat
    ) -> NSImage? {
        guard let selectionMask = selection.layerMask(
            layerFrame: layerFrame,
            layerSize: size,
            canvasSize: canvasSize,
            feather: feather
        ) else { return nil }

        let localizedPattern = ImageEditorSelectionPatternAlignment.localizedContent(
            pattern,
            layerFrame: layerFrame,
            alignsWithCanvas: alignsWithCanvas
        )
        let patternImage = localizedPattern.renderedImage(size: size)
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        guard let overlayPixels = patternImage.rgbaPixels(width: width, height: height) else {
            return nil
        }
        return compositedSelectionFill(
            selectionMask: selectionMask,
            opacity: opacity,
            blendMode: blendMode
        ) { offset in
            let alpha = Double(overlayPixels[offset + 3]) / 255
            return (
                red: alpha > 0 ? Double(overlayPixels[offset]) / 255 / alpha : 0,
                green: alpha > 0 ? Double(overlayPixels[offset + 1]) / 255 / alpha : 0,
                blue: alpha > 0 ? Double(overlayPixels[offset + 2]) / 255 / alpha : 0,
                alpha: alpha
            )
        }
    }

    func historyFilled(
        from sourceImage: NSImage,
        sourceLayerFrame: CGRect,
        selection: ImageEditorSelection,
        layerFrame: CGRect,
        canvasSize: CGSize,
        opacity: CGFloat,
        blendMode: ImageEditorBlendMode,
        feather: CGFloat
    ) -> NSImage? {
        guard layerFrame.width > 0,
              layerFrame.height > 0,
              let selectionMask = selection.layerMask(
                layerFrame: layerFrame,
                layerSize: size,
                canvasSize: canvasSize,
                feather: feather
              )
        else { return nil }

        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        guard let mask = selectionMask.alphaMask(width: width, height: height) else {
            return nil
        }
        return historyRestored(
            from: sourceImage,
            sourceLayerFrame: sourceLayerFrame,
            layerFrame: layerFrame,
            coverage: mask.alpha,
            opacity: opacity,
            blendMode: blendMode
        )
    }

    func historyBrushed(
        from sourceImage: NSImage,
        sourceLayerFrame: CGRect,
        layerFrame: CGRect,
        samples: [ImageEditorBrushStrokeSample],
        settings: ImageEditorBrushStrokeSettings,
        blendMode: ImageEditorBlendMode = .normal
    ) -> NSImage? {
        guard layerFrame.width > 0,
              layerFrame.height > 0,
              !samples.isEmpty
        else { return nil }

        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let normalized = settings.normalized
        let stamps = ImageEditorBrushStrokeKernel.stampSamples(
            samples: samples,
            diameter: normalized.diameter,
            spacing: normalized.spacing,
            smoothing: normalized.smoothing
        )
        let coverage = ImageEditorBrushStrokeKernel.coverage(
            width: width,
            height: height,
            stamps: stamps,
            settings: normalized
        )
        return historyRestored(
            from: sourceImage,
            sourceLayerFrame: sourceLayerFrame,
            layerFrame: layerFrame,
            coverage: coverage,
            opacity: 1,
            blendMode: blendMode == .passThrough ? .normal : blendMode
        )
    }

    private func historyRestored(
        from sourceImage: NSImage,
        sourceLayerFrame: CGRect,
        layerFrame: CGRect,
        coverage inputCoverage: [UInt8],
        opacity: CGFloat,
        blendMode: ImageEditorBlendMode
    ) -> NSImage? {
        guard layerFrame.width > 0,
              layerFrame.height > 0
        else { return nil }

        let alignedSource = NSImage.rendered(size: size) { _ in
            let overlap = sourceLayerFrame.intersection(layerFrame)
            guard !overlap.isNull,
                  overlap.width > 0,
                  overlap.height > 0,
                  sourceLayerFrame.width > 0,
                  sourceLayerFrame.height > 0
            else { return }
            let targetScaleX = size.width / layerFrame.width
            let targetScaleY = size.height / layerFrame.height
            let sourceScaleX = sourceImage.size.width / sourceLayerFrame.width
            let sourceScaleY = sourceImage.size.height / sourceLayerFrame.height
            let destination = CGRect(
                x: (overlap.minX - layerFrame.minX) * targetScaleX,
                y: (layerFrame.maxY - overlap.maxY) * targetScaleY,
                width: overlap.width * targetScaleX,
                height: overlap.height * targetScaleY
            )
            let sourceRect = CGRect(
                x: (overlap.minX - sourceLayerFrame.minX) * sourceScaleX,
                y: (sourceLayerFrame.maxY - overlap.maxY) * sourceScaleY,
                width: overlap.width * sourceScaleX,
                height: overlap.height * sourceScaleY
            )
            sourceImage.draw(
                in: destination,
                from: sourceRect,
                operation: .copy,
                fraction: 1
            )
        }
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        guard var pixels = rgbaPixels(width: width, height: height),
              let sourcePixels = alignedSource?.rgbaPixels(width: width, height: height),
              inputCoverage.count == width * height
        else { return nil }

        let normalizedOpacity = Double(max(0, min(1, opacity)))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let offset = y * bytesPerRow + x * bytesPerPixel
                var coverage = Double(inputCoverage[pixelIndex]) / 255 * normalizedOpacity
                guard coverage > 0 else { continue }
                if blendMode == .dissolve {
                    coverage = Self.selectionFillDissolves(
                        x: x,
                        y: y,
                        probability: coverage
                    ) ? 1 : 0
                    guard coverage > 0 else { continue }
                }

                let baseAlpha = Double(pixels[offset + 3]) / 255
                let sourceAlpha = Double(sourcePixels[offset + 3]) / 255
                let baseRed = baseAlpha > 0 ? Double(pixels[offset]) / 255 / baseAlpha : 0
                let baseGreen = baseAlpha > 0 ? Double(pixels[offset + 1]) / 255 / baseAlpha : 0
                let baseBlue = baseAlpha > 0 ? Double(pixels[offset + 2]) / 255 / baseAlpha : 0
                let sourceRed = sourceAlpha > 0 ? Double(sourcePixels[offset]) / 255 / sourceAlpha : 0
                let sourceGreen = sourceAlpha > 0 ? Double(sourcePixels[offset + 1]) / 255 / sourceAlpha : 0
                let sourceBlue = sourceAlpha > 0 ? Double(sourcePixels[offset + 2]) / 255 / sourceAlpha : 0
                let blended = blendMode.blend(
                    baseRed: baseRed,
                    baseGreen: baseGreen,
                    baseBlue: baseBlue,
                    overlayRed: sourceRed,
                    overlayGreen: sourceGreen,
                    overlayBlue: sourceBlue
                )
                let targetRed = sourceAlpha * ((1 - baseAlpha) * sourceRed + baseAlpha * blended.red)
                let targetGreen = sourceAlpha * ((1 - baseAlpha) * sourceGreen + baseAlpha * blended.green)
                let targetBlue = sourceAlpha * ((1 - baseAlpha) * sourceBlue + baseAlpha * blended.blue)
                let inverseCoverage = 1 - coverage
                pixels[offset] = Self.selectionFillByte(
                    Double(pixels[offset]) / 255 * inverseCoverage + targetRed * coverage
                )
                pixels[offset + 1] = Self.selectionFillByte(
                    Double(pixels[offset + 1]) / 255 * inverseCoverage + targetGreen * coverage
                )
                pixels[offset + 2] = Self.selectionFillByte(
                    Double(pixels[offset + 2]) / 255 * inverseCoverage + targetBlue * coverage
                )
                pixels[offset + 3] = Self.selectionFillByte(
                    baseAlpha * inverseCoverage + sourceAlpha * coverage
                )
            }
        }

        return NSImage.rgbaImage(width: width, height: height, pixels: pixels, size: size)
    }

    private func compositedSelectionFill(
        selectionMask: NSImage,
        opacity: CGFloat,
        blendMode: ImageEditorBlendMode,
        overlayAtOffset: (Int) -> (red: Double, green: Double, blue: Double, alpha: Double)
    ) -> NSImage? {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        guard var pixels = rgbaPixels(width: width, height: height),
              let mask = selectionMask.alphaMask(width: width, height: height)
        else { return nil }

        let normalizedOpacity = Double(max(0, min(1, opacity)))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let offset = y * bytesPerRow + x * bytesPerPixel
                var sourceAlpha = Double(mask.alpha[pixelIndex]) / 255
                    * normalizedOpacity
                guard sourceAlpha > 0 else { continue }
                let overlay = overlayAtOffset(offset)
                sourceAlpha *= overlay.alpha
                guard sourceAlpha > 0 else { continue }
                if blendMode == .dissolve {
                    sourceAlpha = Self.selectionFillDissolves(
                        x: x,
                        y: y,
                        probability: sourceAlpha
                    ) ? 1 : 0
                    guard sourceAlpha > 0 else { continue }
                }

                let baseAlpha = Double(pixels[offset + 3]) / 255
                let baseRed = baseAlpha > 0 ? Double(pixels[offset]) / 255 / baseAlpha : 0
                let baseGreen = baseAlpha > 0 ? Double(pixels[offset + 1]) / 255 / baseAlpha : 0
                let baseBlue = baseAlpha > 0 ? Double(pixels[offset + 2]) / 255 / baseAlpha : 0
                let blended = blendMode.blend(
                    baseRed: baseRed,
                    baseGreen: baseGreen,
                    baseBlue: baseBlue,
                    overlayRed: overlay.red,
                    overlayGreen: overlay.green,
                    overlayBlue: overlay.blue
                )
                let outputAlpha = sourceAlpha + baseAlpha * (1 - sourceAlpha)
                let baseContribution = baseAlpha * (1 - sourceAlpha)
                let sourceAgainstTransparency = 1 - baseAlpha
                let outputRed = sourceAlpha * (sourceAgainstTransparency * overlay.red + baseAlpha * blended.red)
                    + baseContribution * baseRed
                let outputGreen = sourceAlpha * (sourceAgainstTransparency * overlay.green + baseAlpha * blended.green)
                    + baseContribution * baseGreen
                let outputBlue = sourceAlpha * (sourceAgainstTransparency * overlay.blue + baseAlpha * blended.blue)
                    + baseContribution * baseBlue
                pixels[offset] = Self.selectionFillByte(outputRed)
                pixels[offset + 1] = Self.selectionFillByte(outputGreen)
                pixels[offset + 2] = Self.selectionFillByte(outputBlue)
                pixels[offset + 3] = Self.selectionFillByte(outputAlpha)
            }
        }

        return NSImage.rgbaImage(width: width, height: height, pixels: pixels, size: size)
    }

    private static func selectionFillByte(_ value: Double) -> UInt8 {
        UInt8((max(0, min(1, value)) * 255).rounded())
    }

    private static func selectionFillDissolves(x: Int, y: Int, probability: Double) -> Bool {
        if probability <= 0 { return false }
        if probability >= 1 { return true }
        var value = UInt64(truncatingIfNeeded: x)
            &* 0x9E37_79B9_7F4A_7C15
            &+ UInt64(truncatingIfNeeded: y)
            &* 0xBF58_476D_1CE4_E5B9
            &+ 0x94D0_49BB_1331_11EB
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        let sample = Double(value & 0xffff) / 65_535
        return sample < probability
    }

    func stroked(
        selection: ImageEditorSelection,
        layerFrame: CGRect,
        canvasSize: CGSize,
        color: NSColor,
        width: CGFloat,
        opacity: CGFloat,
        feather: CGFloat
    ) -> NSImage? {
        guard let stroke = selection.layerStroke(
            layerFrame: layerFrame,
            layerSize: size,
            canvasSize: canvasSize,
            color: color,
            width: width,
            opacity: opacity,
            feather: feather
        ) else { return nil }

        return NSImage.rendered(size: size) { rect in
            draw(in: rect, from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            stroke.draw(in: rect, from: CGRect(origin: .zero, size: stroke.size), operation: .sourceOver, fraction: 1)
        }
    }

    func copied(
        selection: ImageEditorSelection,
        layerFrame: CGRect,
        canvasSize: CGSize,
        feather: CGFloat
    ) -> NSImage? {
        guard let selectionMask = selection.layerMask(
            layerFrame: layerFrame,
            layerSize: size,
            canvasSize: canvasSize,
            feather: feather
        ) else { return nil }

        return NSImage.rendered(size: size) { rect in
            draw(in: rect, from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            selectionMask.draw(
                in: rect,
                from: CGRect(origin: .zero, size: selectionMask.size),
                operation: .destinationIn,
                fraction: 1
            )
        }
    }

    func contentAwareFilled(
        selection: ImageEditorSelection,
        layerFrame: CGRect,
        canvasSize: CGSize,
        opacity: CGFloat,
        blendMode: ImageEditorBlendMode,
        colorAdaptation: Bool,
        feather: CGFloat
    ) -> NSImage? {
        guard let selectionMask = selection.layerMask(
            layerFrame: layerFrame,
            layerSize: size,
            canvasSize: canvasSize,
            feather: feather
        ) else { return nil }

        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        guard let pixels = rgbaPixels(width: width, height: height),
              let mask = selectionMask.alphaMask(width: width, height: height)
        else { return nil }

        let selectedAlpha = mask.alpha
        guard selectedAlpha.contains(where: { $0 > 0 }) else { return nil }
        guard let fallback = contentAwareFallbackColor(pixels: pixels, mask: selectedAlpha, width: width, height: height) else {
            return nil
        }

        let sourcePixels = pixels
        let bytesPerPixel = 4
        let maxRadius = max(8, min(48, max(width, height) / 4))
        return compositedSelectionFill(
            selectionMask: selectionMask,
            opacity: opacity,
            blendMode: blendMode
        ) { offset in
            let pixelIndex = offset / bytesPerPixel
            let x = pixelIndex % width
            let y = pixelIndex / width
            let replacement = colorAdaptation
                ? contentAwareColor(
                    x: x,
                    y: y,
                    pixels: sourcePixels,
                    mask: selectedAlpha,
                    width: width,
                    height: height,
                    maxRadius: maxRadius,
                    fallback: fallback
                )
                : fallback
            let alpha = Double(replacement.alpha) / 255
            return (
                red: alpha > 0 ? Double(replacement.red) / 255 / alpha : 0,
                green: alpha > 0 ? Double(replacement.green) / 255 / alpha : 0,
                blue: alpha > 0 ? Double(replacement.blue) / 255 / alpha : 0,
                alpha: alpha
            )
        }
    }

    func patched(
        selection: ImageEditorSelection,
        layerFrame: CGRect,
        canvasSize: CGSize,
        offsetInCanvas: CGSize,
        opacity: CGFloat,
        feather: CGFloat,
        extractsTextureTransparently: Bool = false,
        diffusion: Int = 1,
        samplingImage: NSImage? = nil
    ) -> NSImage? {
        guard layerFrame.width > 0,
              layerFrame.height > 0,
              let selectionMask = selection.layerMask(
                layerFrame: layerFrame,
                layerSize: size,
                canvasSize: canvasSize,
                feather: feather
              )
        else { return nil }

        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        guard var pixels = rgbaPixels(width: width, height: height),
              let mask = selectionMask.alphaMask(width: width, height: height)
        else { return nil }

        let selectedAlpha = mask.alpha
        guard selectedAlpha.contains(where: { $0 > 0 }) else { return nil }
        let samplingBaseImage = samplingImage ?? self
        let samplingBasePixels: [UInt8]
        if samplingImage == nil {
            samplingBasePixels = pixels
        } else {
            guard let sampledPixels = samplingBaseImage.rgbaPixels(width: width, height: height)
            else { return nil }
            samplingBasePixels = sampledPixels
        }
        let normalizedDiffusion = max(1, min(7, diffusion))
        let diffusionRadius = CGFloat(normalizedDiffusion - 1) * 0.5
        let sampledImage: NSImage
        let sourcePixels: [UInt8]
        if diffusionRadius > 0 {
            guard let diffusedImage = samplingBaseImage.blurred(radius: diffusionRadius),
                  let diffusedPixels = diffusedImage.rgbaPixels(width: width, height: height)
            else { return nil }
            sampledImage = diffusedImage
            sourcePixels = diffusedPixels
        } else {
            sampledImage = samplingBaseImage
            sourcePixels = samplingBasePixels
        }
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let sourceDeltaX = Int((offsetInCanvas.width * CGFloat(width) / layerFrame.width).rounded())
        let sourceDeltaY = Int((offsetInCanvas.height * CGFloat(height) / layerFrame.height).rounded())
        let normalizedOpacity = max(0, min(1, opacity))
        let textureSampler: PatchTransparentTextureSampler?
        if extractsTextureTransparently {
            guard let localBaselinePixels = sampledImage.blurred(
                radius: PatchTransparentTextureSampler.textureRadius
            )?.rgbaPixels(width: width, height: height) else { return nil }
            textureSampler = PatchTransparentTextureSampler(
                pixels: sourcePixels,
                localBaselinePixels: localBaselinePixels,
                width: width
            )
        } else {
            textureSampler = nil
        }

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let maskAlpha = CGFloat(selectedAlpha[pixelIndex]) / 255 * normalizedOpacity
                guard maskAlpha > 0 else { continue }

                let sourceX = x + sourceDeltaX
                let sourceY = y + sourceDeltaY
                guard sourceX >= 0,
                      sourceX < width,
                      sourceY >= 0,
                      sourceY < height
                else { continue }

                let offset = y * bytesPerRow + x * bytesPerPixel
                let sourceOffset = sourceY * bytesPerRow + sourceX * bytesPerPixel
                if let textureSampler {
                    textureSampler.applyTexture(
                        fromX: sourceX,
                        sourceY: sourceY,
                        to: &pixels,
                        targetOffset: offset,
                        maskAlpha: maskAlpha
                    )
                    continue
                }
                let inverseAlpha = 1 - maskAlpha
                pixels[offset] = blendedByte(original: pixels[offset], replacement: CGFloat(sourcePixels[sourceOffset]), alpha: maskAlpha, inverseAlpha: inverseAlpha)
                pixels[offset + 1] = blendedByte(original: pixels[offset + 1], replacement: CGFloat(sourcePixels[sourceOffset + 1]), alpha: maskAlpha, inverseAlpha: inverseAlpha)
                pixels[offset + 2] = blendedByte(original: pixels[offset + 2], replacement: CGFloat(sourcePixels[sourceOffset + 2]), alpha: maskAlpha, inverseAlpha: inverseAlpha)
                pixels[offset + 3] = blendedByte(original: pixels[offset + 3], replacement: CGFloat(sourcePixels[sourceOffset + 3]), alpha: maskAlpha, inverseAlpha: inverseAlpha)
            }
        }

        return NSImage.rgbaImage(width: width, height: height, pixels: pixels, size: size)
    }

    func cleared(
        selection: ImageEditorSelection,
        layerFrame: CGRect,
        canvasSize: CGSize,
        feather: CGFloat
    ) -> NSImage? {
        guard let selectionMask = selection.layerMask(
            layerFrame: layerFrame,
            layerSize: size,
            canvasSize: canvasSize,
            feather: feather
        ) else { return nil }

        return NSImage.rendered(size: size) { rect in
            draw(in: rect, from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            selectionMask.draw(
                in: rect,
                from: CGRect(origin: .zero, size: selectionMask.size),
                operation: .destinationOut,
                fraction: 1
            )
        }
    }

    private func contentAwareFallbackColor(
        pixels: [UInt8],
        mask: [UInt8],
        width: Int,
        height: Int
    ) -> ContentAwareColor? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var count: CGFloat = 0

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let offset = y * bytesPerRow + x * bytesPerPixel
                guard mask[pixelIndex] == 0,
                      pixels[offset + 3] > 0
                else { continue }
                red += CGFloat(pixels[offset])
                green += CGFloat(pixels[offset + 1])
                blue += CGFloat(pixels[offset + 2])
                alpha += CGFloat(pixels[offset + 3])
                count += 1
            }
        }

        guard count > 0 else { return nil }
        return ContentAwareColor(red: red / count, green: green / count, blue: blue / count, alpha: alpha / count)
    }

    private func contentAwareColor(
        x: Int,
        y: Int,
        pixels: [UInt8],
        mask: [UInt8],
        width: Int,
        height: Int,
        maxRadius: Int,
        fallback: ContentAwareColor
    ) -> ContentAwareColor {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var weightTotal: CGFloat = 0
        var sampleCount = 0

        for radius in 1...maxRadius {
            let minX = max(0, x - radius)
            let maxX = min(width - 1, x + radius)
            let minY = max(0, y - radius)
            let maxY = min(height - 1, y + radius)

            for sampleY in minY...maxY {
                for sampleX in minX...maxX {
                    guard sampleX == minX || sampleX == maxX || sampleY == minY || sampleY == maxY else { continue }
                    let sampleIndex = sampleY * width + sampleX
                    let offset = sampleY * bytesPerRow + sampleX * bytesPerPixel
                    guard mask[sampleIndex] == 0,
                          pixels[offset + 3] > 0
                    else { continue }

                    let dx = CGFloat(sampleX - x)
                    let dy = CGFloat(sampleY - y)
                    let weight = 1 / max(1, dx * dx + dy * dy)
                    red += CGFloat(pixels[offset]) * weight
                    green += CGFloat(pixels[offset + 1]) * weight
                    blue += CGFloat(pixels[offset + 2]) * weight
                    alpha += CGFloat(pixels[offset + 3]) * weight
                    weightTotal += weight
                    sampleCount += 1
                }
            }

            if sampleCount >= 12 {
                break
            }
        }

        guard weightTotal > 0 else { return fallback }
        return ContentAwareColor(red: red / weightTotal, green: green / weightTotal, blue: blue / weightTotal, alpha: alpha / weightTotal)
    }

    private func rgbaPixels(width: Int, height: Int) -> [UInt8]? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private func blendedByte(original: UInt8, replacement: CGFloat, alpha: CGFloat, inverseAlpha: CGFloat) -> UInt8 {
        UInt8(max(0, min(255, (CGFloat(original) * inverseAlpha + replacement * alpha).rounded())))
    }
}

private struct ContentAwareColor {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat
}

private extension NSImage {
    static func rgbaImage(width: Int, height: Int, pixels: [UInt8], size: CGSize) -> NSImage? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        guard pixels.count == bytesPerRow * height,
              let provider = CGDataProvider(data: Data(pixels) as CFData),
              let output = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else { return nil }

        return NSImage(cgImage: output, size: size)
    }
}

private extension ImageEditorSelection {
    func patchTranslated(by delta: CGSize, canvasSize: CGSize) -> ImageEditorSelection? {
        guard rasterMask == nil else {
            return translated(by: delta, canvasSize: canvasSize)
        }
        let translatedPoints = points.map {
            CGPoint(x: $0.x + delta.width, y: $0.y + delta.height)
        }
        guard translatedPoints.count >= 3 else { return nil }
        return ImageEditorSelection(
            points: translatedPoints,
            isPolygon: isPolygon,
            isInverted: isInverted,
            rasterMask: nil
        )
    }

    func layerMask(layerFrame: CGRect, layerSize: CGSize, canvasSize: CGSize, feather: CGFloat) -> NSImage? {
        guard layerSize.width > 0,
              layerSize.height > 0,
              layerFrame.width > 0,
              layerFrame.height > 0,
              let canvasMask = canvasMask(size: canvasSize, feather: feather)
        else { return nil }

        return NSImage.rendered(size: layerSize) { _ in
            canvasMask.draw(
                in: CGRect(origin: .zero, size: layerSize),
                from: CGRect(
                    x: layerFrame.minX,
                    y: canvasSize.height - layerFrame.maxY,
                    width: layerFrame.width,
                    height: layerFrame.height
                ),
                operation: .copy,
                fraction: 1
            )
        }
    }

    func layerStroke(
        layerFrame: CGRect,
        layerSize: CGSize,
        canvasSize: CGSize,
        color: NSColor,
        width: CGFloat,
        opacity: CGFloat,
        feather: CGFloat
    ) -> NSImage? {
        guard layerSize.width > 0,
              layerSize.height > 0,
              layerFrame.width > 0,
              layerFrame.height > 0,
              let canvasStroke = canvasStroke(size: canvasSize, color: color, width: width, opacity: opacity, feather: feather)
        else { return nil }

        return NSImage.rendered(size: layerSize) { _ in
            canvasStroke.draw(
                in: CGRect(origin: .zero, size: layerSize),
                from: CGRect(
                    x: layerFrame.minX,
                    y: canvasSize.height - layerFrame.maxY,
                    width: layerFrame.width,
                    height: layerFrame.height
                ),
                operation: .copy,
                fraction: 1
            )
        }
    }

    func canvasMask(size: CGSize, feather: CGFloat) -> NSImage? {
        if let rasterMask,
           let image = NSImage.selectionMaskImage(rasterMask, inverted: isInverted, targetSize: size) {
            guard feather > 0 else { return image }
            return image.blurred(radius: feather) ?? image
        }

        let hardMask = NSImage.rendered(size: size) { rect in
            let maskPath = self.path()
            if isInverted {
                NSColor.white.setFill()
                rect.fill()
                NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: size.height) {
                    guard let context = NSGraphicsContext.current?.cgContext else { return }
                    context.saveGState()
                    context.setBlendMode(.clear)
                    NSColor.clear.setFill()
                    maskPath.fill()
                    context.restoreGState()
                }
            } else {
                NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: size.height) {
                    NSColor.white.setFill()
                    maskPath.fill()
                }
            }
        }
        guard let hardMask, feather > 0 else { return hardMask }
        return hardMask.blurred(radius: feather) ?? hardMask
    }

    func canvasStroke(size: CGSize, color: NSColor, width: CGFloat, opacity: CGFloat, feather: CGFloat) -> NSImage? {
        let strokeImage = NSImage.rendered(size: size) { _ in
            let strokePath = self.path()
            strokePath.lineJoinStyle = .miter
            strokePath.lineCapStyle = .butt
            strokePath.lineWidth = max(1, width)
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: size.height) {
                color.withAlphaComponent(opacity).setStroke()
                strokePath.stroke()
            }
        }
        guard let strokeImage, feather > 0 else { return strokeImage }
        return strokeImage.blurred(radius: feather) ?? strokeImage
    }
}
