//
//  ImageEditorSelectionCommands.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

private let defaultLayerTransparencySelectionThreshold = 8

@MainActor
extension ImageEditorViewModel {
    var canLoadSelectionFromLayerTransparency: Bool {
        if let cachedLayerTransparencySelectionAvailability {
            return cachedLayerTransparencySelectionAvailability
        }

        let isAvailable = !layerTransparencySelections().isEmpty
        cachedLayerTransparencySelectionAvailability = isAvailable
        return isAvailable
    }

    var hasSavedSelection: Bool {
        document.savedSelection != nil
    }

    var canReselectSelection: Bool {
        reselectableSelection != nil && document.selection == nil
    }

    var canSelectSimilarColors: Bool {
        hasSelection
    }

    var canGrowColorSelection: Bool {
        hasSelection
    }

    func selectAll() {
        let fullCanvasSelection = ImageEditorSelection.fullCanvas(size: document.canvasSize)
        guard !selectionsAreEquivalent(document.selection, fullCanvasSelection) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        pushUndo()
        document.selection = fullCanvasSelection
        appendHistory(L10n.text("imageEditor.history.selectionAll"))
        statusText = L10n.text("imageEditor.status.selectionAll")
    }

    func loadSelectionFromLayerTransparency(threshold requestedThreshold: Int? = nil) {
        let selections = layerTransparencySelections(threshold: requestedThreshold)
        guard let selection = combinedTransparencySelections(selections) else {
            statusText = L10n.text("imageEditor.status.selectionFromLayerFailed")
            return
        }

        let historyKey = selections.count == 1
            ? "imageEditor.history.selectionFromLayer"
            : "imageEditor.history.selectionFromSelectedLayers"
        let didChangeSelection = applySelectionCandidate(selection, replaceHistoryKey: historyKey)
        if didChangeSelection, document.selection != nil, selections.count > 1 {
            statusText = L10n.format("imageEditor.status.selectionFromSelectedLayers", selections.count)
        }
    }

    func saveCurrentSelection() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard !selectionsAreEquivalent(document.savedSelection, selection) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        pushUndo()
        document.savedSelection = selection
        appendHistory(L10n.text("imageEditor.history.selectionSaved"))
        statusText = L10n.text("imageEditor.status.selectionSaved")
    }

    func reselectSelection() {
        guard let selection = reselectableSelection else {
            statusText = L10n.text("imageEditor.status.noReselectSelection")
            return
        }
        guard !selectionsAreEquivalent(document.selection, selection) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        pushUndo()
        document.selection = selection
        appendHistory(L10n.text("imageEditor.history.selectionReselected"))
        statusText = L10n.text("imageEditor.status.selectionReselected")
    }

    func restoreSavedSelection() {
        guard let selection = document.savedSelection else {
            statusText = L10n.text("imageEditor.status.noSavedSelection")
            return
        }
        guard !selectionsAreEquivalent(document.selection, selection) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        pushUndo()
        document.selection = selection
        appendHistory(L10n.text("imageEditor.history.selectionRestored"))
        statusText = L10n.text("imageEditor.status.selectionRestored")
    }

    func selectColorRangeFromForeground(tolerance requestedTolerance: CGFloat? = nil) {
        let effectiveTolerance = effectiveSelectionTolerance(requestedTolerance)
        guard let selection = currentImage.colorRangeSelection(
            targetColor: foregroundColor,
            tolerance: effectiveTolerance,
            canvasSize: document.canvasSize,
            inverted: false
        ) else {
            statusText = L10n.text("imageEditor.status.selectionColorRangeEmpty")
            return
        }

        applySelectionCandidate(selection, replaceHistoryKey: "imageEditor.history.selectionColorRange")
    }

    func presentColorRangePanel() {
        let color = foregroundColor.usingColorSpace(.deviceRGB) ?? foregroundColor
        colorRangeColor = color
        colorRangeIncludeColors = [color]
        colorRangeExcludeColors = []
        colorRangeSampleMode = .replace
        colorRangeTolerance = tolerance
        colorRangeInverted = false
        isColorRangeSheetPresented = true
        statusText = L10n.text("imageEditor.status.selectionColorRangePanel")
    }

    func applyColorRangeSelectionFromPanel() {
        guard let selection = currentImage.colorRangeSelection(
            targetColors: colorRangeTargetColors,
            excludedColors: colorRangeExcludeColors,
            tolerance: colorRangeTolerance,
            canvasSize: document.canvasSize,
            inverted: colorRangeInverted
        ) else {
            statusText = L10n.text("imageEditor.status.selectionColorRangeEmpty")
            return
        }

        foregroundColor = colorRangeColor
        tolerance = colorRangeTolerance
        isColorRangeSheetPresented = false
        applySelectionCandidate(selection, replaceHistoryKey: "imageEditor.history.selectionColorRange")
    }

    func selectSimilarColors(tolerance requestedTolerance: CGFloat? = nil) {
        let effectiveTolerance = effectiveSelectionTolerance(requestedTolerance)
        guard let sourceSelection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        let samples = colorRangeSamples(from: sourceSelection)
        guard !samples.isEmpty else {
            statusText = L10n.text("imageEditor.status.selectionSimilarSampleEmpty")
            return
        }
        guard let selection = currentImage.colorRangeSelection(
            targetColors: samples,
            tolerance: effectiveTolerance,
            canvasSize: document.canvasSize,
            inverted: false
        ) else {
            statusText = L10n.text("imageEditor.status.selectionColorRangeEmpty")
            return
        }

        applySelectionCandidate(selection, replaceHistoryKey: "imageEditor.history.selectionSimilar")
    }

    func growColorSelection(tolerance requestedTolerance: CGFloat? = nil) {
        let effectiveTolerance = effectiveSelectionTolerance(requestedTolerance)
        guard let sourceSelection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard let selection = currentImage.grownColorSelection(
            from: sourceSelection,
            tolerance: effectiveTolerance,
            canvasSize: document.canvasSize
        ) else {
            statusText = L10n.text("imageEditor.status.selectionSimilarSampleEmpty")
            return
        }
        guard !selectionsAreEquivalent(sourceSelection, selection) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        pushUndo()
        document.selection = selection
        appendHistory(L10n.text("imageEditor.history.selectionGrow"))
        statusText = L10n.text("imageEditor.status.selectionGrown")
    }

    func sampleColorRangeColor(at point: CGPoint) {
        guard let color = currentImage.color(
            at: point,
            coordinateSize: document.canvasSize
        )?.usingColorSpace(.deviceRGB) else { return }
        colorRangeColor = color
        switch colorRangeSampleMode {
        case .replace:
            colorRangeIncludeColors = [color]
            colorRangeExcludeColors = []
            statusText = L10n.text("imageEditor.status.selectionColorRangeSampled")
        case .add:
            colorRangeIncludeColors.appendUniqueColorRangeSample(color)
            statusText = L10n.text("imageEditor.status.selectionColorRangeSampleAdded")
        case .subtract:
            colorRangeExcludeColors.appendUniqueColorRangeSample(color)
            statusText = L10n.text("imageEditor.status.selectionColorRangeSampleSubtracted")
        }
    }

    func setColorRangePrimaryColor(_ color: NSColor) {
        guard let deviceColor = color.usingColorSpace(.deviceRGB) else { return }
        colorRangeColor = deviceColor
        colorRangeIncludeColors = [deviceColor]
        colorRangeExcludeColors = []
        colorRangeSampleMode = .replace
    }

    var colorRangePreviewImage: NSImage {
        currentImage.colorRangePreviewImage(
            targetColors: colorRangeTargetColors,
            excludedColors: colorRangeExcludeColors,
            tolerance: colorRangeTolerance,
            inverted: colorRangeInverted
        )
    }

    private var colorRangeTargetColors: [NSColor] {
        colorRangeIncludeColors.isEmpty ? [colorRangeColor] : colorRangeIncludeColors
    }

    func expandSelection(radius: Int? = nil) {
        modifySelectionBoundary(expanding: true, radius: radius)
    }

    func contractSelection(radius: Int? = nil) {
        modifySelectionBoundary(expanding: false, radius: radius)
    }

    func featherSelection(radius: Int? = nil) {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        let effectiveRadius = effectiveSelectionRadius(radius, maximum: 64)
        let modified = selection.feathered(by: effectiveRadius, canvasSize: document.canvasSize)
        commitSelectionBoundaryResult(
            original: selection,
            modified: modified,
            radius: effectiveRadius,
            historyKey: "imageEditor.history.selectionFeather",
            statusKey: "imageEditor.status.selectionFeathered"
        )
    }

    func borderSelection(radius: Int? = nil) {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        let effectiveRadius = effectiveSelectionRadius(radius, maximum: 64)
        let modified = selection.bordered(by: effectiveRadius, canvasSize: document.canvasSize)
        commitSelectionBoundaryResult(
            original: selection,
            modified: modified,
            radius: effectiveRadius,
            historyKey: "imageEditor.history.selectionBorder",
            statusKey: "imageEditor.status.selectionBordered"
        )
    }

    func smoothSelection(radius: Int? = nil) {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        let effectiveRadius = effectiveSelectionRadius(radius, maximum: 16)
        let modified = selection.smoothed(by: effectiveRadius, canvasSize: document.canvasSize)
        guard !selectionsAreEquivalent(selection, modified) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        pushUndo()
        document.selection = modified
        appendHistory(L10n.text("imageEditor.history.selectionSmooth"))
        statusText = modified == nil
            ? L10n.text("imageEditor.status.selectionEmpty")
            : L10n.format("imageEditor.status.selectionSmoothed", effectiveRadius)
    }

    func fillSelectionHoles() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard let modified = selection.filledHoles(canvasSize: document.canvasSize) else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return
        }
        guard !selectionsAreEquivalent(selection, modified) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        pushUndo()
        document.selection = modified
        appendHistory(L10n.text("imageEditor.history.selectionFillHoles"))
        statusText = L10n.text("imageEditor.status.selectionFillHoles")
    }

    func removeSelectionSpeckles(maximumArea: Int? = nil) {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        let effectiveMaximumArea = effectiveSelectionRadius(maximumArea, maximum: 64)
        let modified = selection.removedSpeckles(
            maximumArea: effectiveMaximumArea,
            canvasSize: document.canvasSize
        )
        guard !selectionsAreEquivalent(selection, modified) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        pushUndo()
        document.selection = modified
        appendHistory(L10n.text("imageEditor.history.selectionRemoveSpeckles"))
        statusText = modified == nil
            ? L10n.text("imageEditor.status.selectionEmpty")
            : L10n.format("imageEditor.status.selectionSpecklesRemoved", effectiveMaximumArea)
    }

    func moveSelectionLeft() {
        moveSelection(by: CGSize(width: -selectionMoveAmount, height: 0))
    }

    func moveSelectionRight() {
        moveSelection(by: CGSize(width: selectionMoveAmount, height: 0))
    }

    func moveSelectionUp() {
        moveSelection(by: CGSize(width: 0, height: selectionMoveAmount))
    }

    func moveSelectionDown() {
        moveSelection(by: CGSize(width: 0, height: -selectionMoveAmount))
    }

    func nudgeSelection(by delta: CGSize) {
        moveSelection(by: delta)
    }

    func centerSelectionHorizontally() {
        centerSelection(horizontal: true, vertical: false)
    }

    func centerSelectionVertically() {
        centerSelection(horizontal: false, vertical: true)
    }

    func centerSelectionInCanvas() {
        centerSelection(horizontal: true, vertical: true)
    }

    func flipSelectionHorizontal() {
        flipSelection(horizontal: true)
    }

    func flipSelectionVertical() {
        flipSelection(horizontal: false)
    }

    func rotateSelectionClockwise() {
        rotateSelection(clockwiseTurns: 1)
    }

    func rotateSelectionCounterclockwise() {
        rotateSelection(clockwiseTurns: -1)
    }

    func rotateSelection180() {
        rotateSelection(clockwiseTurns: 2)
    }

    func scaleSelectionUp() {
        scaleSelection(by: 2, historyKey: "imageEditor.history.selectionScaleUp", statusKey: "imageEditor.status.selectionScaledUp")
    }

    func scaleSelectionDown() {
        scaleSelection(by: 0.5, historyKey: "imageEditor.history.selectionScaleDown", statusKey: "imageEditor.status.selectionScaledDown")
    }

    func fitSelectionToCanvas() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard let modified = selection.fittedToCanvas(canvasSize: document.canvasSize) else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return
        }
        guard !selectionsAreEquivalent(selection, modified) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        pushUndo()
        document.selection = modified
        appendHistory(L10n.text("imageEditor.history.selectionFitCanvas"))
        statusText = L10n.text("imageEditor.status.selectionFitCanvas")
    }

    private var selectionMoveAmount: CGFloat {
        CGFloat(max(1, min(512, Int(selectionModifyAmount.rounded()))))
    }

    private func moveSelection(by delta: CGSize) {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        let modified = selection.translated(by: delta, canvasSize: document.canvasSize)
        guard !selectionsAreEquivalent(selection, modified) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        pushUndo()
        document.selection = modified
        appendHistory(L10n.text("imageEditor.history.selectionMove"))
        statusText = modified == nil
            ? L10n.text("imageEditor.status.selectionEmpty")
            : L10n.format(
                "imageEditor.status.selectionMoved",
                Int(delta.width.rounded()),
                Int(delta.height.rounded())
            )
    }

    private func centerSelection(horizontal: Bool, vertical: Bool) {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }

        guard let bounds = selection.effectiveSelectedBounds(in: document.canvasSize) else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return
        }
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        let delta = CGSize(
            width: horizontal ? canvasBounds.midX - bounds.midX : 0,
            height: vertical ? canvasBounds.midY - bounds.midY : 0
        )
        guard let modified = selection.translated(by: delta, canvasSize: document.canvasSize) else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return
        }
        guard !selectionsAreEquivalent(selection, modified) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        let historyKey: String
        let statusKey: String
        switch (horizontal, vertical) {
        case (true, true):
            historyKey = "imageEditor.history.selectionCenterCanvas"
            statusKey = "imageEditor.status.selectionCenteredCanvas"
        case (true, false):
            historyKey = "imageEditor.history.selectionCenterHorizontal"
            statusKey = "imageEditor.status.selectionCenteredHorizontal"
        case (false, true):
            historyKey = "imageEditor.history.selectionCenterVertical"
            statusKey = "imageEditor.status.selectionCenteredVertical"
        case (false, false):
            return
        }

        pushUndo()
        document.selection = modified
        appendHistory(L10n.text(historyKey))
        statusText = L10n.text(statusKey)
    }

    private func flipSelection(horizontal: Bool) {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard let modified = selection.flipped(horizontal: horizontal, canvasSize: document.canvasSize) else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return
        }
        guard !selectionsAreEquivalent(selection, modified) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        pushUndo()
        document.selection = modified
        appendHistory(L10n.text(horizontal ? "imageEditor.history.selectionFlipHorizontal" : "imageEditor.history.selectionFlipVertical"))
        statusText = L10n.text(horizontal ? "imageEditor.status.selectionFlippedHorizontal" : "imageEditor.status.selectionFlippedVertical")
    }

    private func rotateSelection(clockwiseTurns: Int) {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard let modified = selection.rotatedQuarterTurns(
            clockwiseTurns: clockwiseTurns,
            canvasSize: document.canvasSize
        ) else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return
        }
        guard !selectionsAreEquivalent(selection, modified) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        let normalizedTurns = ((clockwiseTurns % 4) + 4) % 4
        let historyKey: String
        let statusKey: String
        switch normalizedTurns {
        case 1:
            historyKey = "imageEditor.history.selectionRotateClockwise"
            statusKey = "imageEditor.status.selectionRotatedClockwise"
        case 2:
            historyKey = "imageEditor.history.selectionRotate180"
            statusKey = "imageEditor.status.selectionRotated180"
        case 3:
            historyKey = "imageEditor.history.selectionRotateCounterclockwise"
            statusKey = "imageEditor.status.selectionRotatedCounterclockwise"
        default:
            return
        }

        pushUndo()
        document.selection = modified
        appendHistory(L10n.text(historyKey))
        statusText = L10n.text(statusKey)
    }

    private func scaleSelection(by factor: CGFloat, historyKey: String, statusKey: String) {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard let modified = selection.scaled(by: factor, canvasSize: document.canvasSize) else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return
        }
        guard !selectionsAreEquivalent(selection, modified) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        pushUndo()
        document.selection = modified
        appendHistory(L10n.text(historyKey))
        statusText = L10n.text(statusKey)
    }

    private func modifySelectionBoundary(expanding: Bool, radius: Int? = nil) {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        let effectiveRadius = effectiveSelectionRadius(radius, maximum: 64)
        let modified = expanding
            ? selection.expanded(by: effectiveRadius, canvasSize: document.canvasSize)
            : selection.contracted(by: effectiveRadius, canvasSize: document.canvasSize)
        guard !selectionsAreEquivalent(selection, modified) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        pushUndo()
        document.selection = modified
        appendHistory(L10n.text(expanding ? "imageEditor.history.selectionExpand" : "imageEditor.history.selectionContract"))
        statusText = modified == nil
            ? L10n.text("imageEditor.status.selectionEmpty")
            : L10n.format(
                expanding ? "imageEditor.status.selectionExpanded" : "imageEditor.status.selectionContracted",
                effectiveRadius
            )
    }

    private func commitSelectionBoundaryResult(
        original: ImageEditorSelection,
        modified: ImageEditorSelection?,
        radius: Int,
        historyKey: String,
        statusKey: String
    ) {
        guard !selectionsAreEquivalent(original, modified) else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        pushUndo()
        document.selection = modified
        appendHistory(L10n.text(historyKey))
        statusText = modified == nil
            ? L10n.text("imageEditor.status.selectionEmpty")
            : L10n.format(statusKey, radius)
    }

    private func effectiveSelectionRadius(_ requested: Int?, maximum: Int) -> Int {
        max(1, min(maximum, requested ?? Int(selectionModifyAmount.rounded())))
    }

    private func effectiveSelectionTolerance(_ requested: CGFloat?) -> CGFloat {
        max(0, min(1, requested ?? tolerance))
    }

    private func transparencySelection(
        forLayerAt index: Int,
        threshold requestedThreshold: Int? = nil
    ) -> ImageEditorSelection? {
        guard document.layers.indices.contains(index) else { return nil }
        let layer = document.layers[index]
        if layer.isGroup {
            return document.compositedImage(includingOnly: [layer.id]).alphaSelection(
                threshold: effectiveLayerTransparencySelectionThreshold(requestedThreshold)
            )
        }

        guard let image = NSImage.rendered(size: document.canvasSize, actions: { _ in
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: document.canvasSize.height) {
                if layer.isClippingMask,
                   let clippedImage = document.clippedCompositingImage(forLayerAt: index) {
                    clippedImage.draw(
                        in: CGRect(origin: .zero, size: document.canvasSize),
                        from: CGRect(origin: .zero, size: document.canvasSize),
                        operation: .sourceOver,
                        fraction: 1
                    )
                } else {
                    let compositingImage = layer.renderedCompositingImage(globalLightAngle: document.globalLightAngle)
                    compositingImage.draw(
                        in: layer.renderedCompositingFrame(globalLightAngle: document.globalLightAngle),
                        from: CGRect(origin: .zero, size: compositingImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                }
            }
        }) else { return nil }
        return image.alphaSelection(
            threshold: effectiveLayerTransparencySelectionThreshold(requestedThreshold)
        )
    }

    private func layerTransparencySelections(threshold requestedThreshold: Int? = nil) -> [ImageEditorSelection] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.compactMap { index in
            let layer = document.layers[index]
            guard selectedIDs.contains(layer.id),
                  !layer.isAdjustment,
                  !layer.isFilter
            else { return nil }
            return transparencySelection(forLayerAt: index, threshold: requestedThreshold)
        }
    }

    private func effectiveLayerTransparencySelectionThreshold(_ requestedThreshold: Int?) -> UInt8 {
        let threshold = requestedThreshold ?? defaultLayerTransparencySelectionThreshold
        return UInt8(max(0, min(255, threshold)))
    }

    private func combinedTransparencySelections(
        _ selections: [ImageEditorSelection]
    ) -> ImageEditorSelection? {
        selections.reduce(nil) { current, candidate in
            ImageEditorSelection.combined(
                current: current,
                candidate: candidate,
                mode: .add,
                canvasSize: document.canvasSize
            )
        }
    }

    private func colorRangeSamples(from selection: ImageEditorSelection) -> [NSColor] {
        guard let mask = selection.rasterizedMask(canvasSize: document.canvasSize) else { return [] }
        let selectedPixelCount = mask.alpha.reduce(0) { count, value in
            value > 0 ? count + 1 : count
        }
        guard selectedPixelCount > 0 else { return [] }

        let maxSamples = 48
        let interval = max(1, selectedPixelCount / maxSamples)
        var selectedIndex = 0
        var colors: [NSColor] = []

        for y in 0..<mask.height {
            for x in 0..<mask.width {
                guard mask.alpha[y * mask.width + x] > 0 else { continue }
                defer { selectedIndex += 1 }
                guard selectedIndex % interval == 0 else { continue }
                let point = CGPoint(
                    x: (CGFloat(x) + 0.5) / CGFloat(mask.width) * document.canvasSize.width,
                    y: (CGFloat(y) + 0.5) / CGFloat(mask.height) * document.canvasSize.height
                )
                guard let color = currentImage.color(
                    at: point,
                    coordinateSize: document.canvasSize
                )?.usingColorSpace(.deviceRGB) else { continue }
                colors.appendUniqueColorRangeSample(color)
                if colors.count >= maxSamples {
                    return colors
                }
            }
        }

        return colors
    }
}

private extension Array where Element == NSColor {
    mutating func appendUniqueColorRangeSample(_ color: NSColor) {
        guard !containsColorRangeMatch(
            red: color.redComponent,
            green: color.greenComponent,
            blue: color.blueComponent,
            tolerance: 0.01
        ) else { return }
        append(color)
    }

    func containsColorRangeMatch(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        tolerance: CGFloat
    ) -> Bool {
        contains { target in
            colorRangeDistance(red: red, green: green, blue: blue, target: target) <= tolerance
        }
    }

    private func colorRangeDistance(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        target: NSColor
    ) -> CGFloat {
        let redDelta = red - target.redComponent
        let greenDelta = green - target.greenComponent
        let blueDelta = blue - target.blueComponent
        return sqrt(redDelta * redDelta + greenDelta * greenDelta + blueDelta * blueDelta)
    }
}

extension NSImage {
    func colorRangeSelection(
        targetColor: NSColor,
        tolerance: CGFloat,
        canvasSize: CGSize,
        inverted: Bool = false
    ) -> ImageEditorSelection? {
        colorRangeSelection(
            targetColors: [targetColor],
            excludedColors: [],
            tolerance: tolerance,
            canvasSize: canvasSize,
            inverted: inverted
        )
    }

    func colorRangeSelection(
        targetColors: [NSColor],
        excludedColors: [NSColor] = [],
        tolerance: CGFloat,
        canvasSize: CGSize,
        inverted: Bool = false
    ) -> ImageEditorSelection? {
        let targets = targetColors.compactMap { $0.usingColorSpace(.deviceRGB) }
        let exclusions = excludedColors.compactMap { $0.usingColorSpace(.deviceRGB) }
        guard !targets.isEmpty,
              let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

        let width = max(1, Int(canvasSize.width.rounded()))
        let height = max(1, Int(canvasSize.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let clampedTolerance = max(0, min(1, tolerance))
        var alpha = [UInt8](repeating: 0, count: width * height)
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = y * bytesPerRow + x * bytesPerPixel
                let pixelAlpha = pixels[pixelOffset + 3]
                guard pixelAlpha > 8 else { continue }

                let red = CGFloat(pixels[pixelOffset]) / 255
                let green = CGFloat(pixels[pixelOffset + 1]) / 255
                let blue = CGFloat(pixels[pixelOffset + 2]) / 255
                let isIncluded = targets.containsColorRangeMatch(
                    red: red,
                    green: green,
                    blue: blue,
                    tolerance: clampedTolerance
                )
                let isExcluded = exclusions.containsColorRangeMatch(
                    red: red,
                    green: green,
                    blue: blue,
                    tolerance: clampedTolerance
                )
                let isColorMatch = isIncluded && !isExcluded
                guard inverted ? !isColorMatch : isColorMatch else { continue }

                alpha[y * width + x] = UInt8.max
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        let bounds = CGRect(
            x: CGFloat(minX) / CGFloat(width) * canvasSize.width,
            y: CGFloat(minY) / CGFloat(height) * canvasSize.height,
            width: CGFloat(maxX - minX + 1) / CGFloat(width) * canvasSize.width,
            height: CGFloat(maxY - minY + 1) / CGFloat(height) * canvasSize.height
        )
        return .raster(
            mask: ImageEditorSelectionMask(width: width, height: height, alpha: alpha),
            bounds: bounds
        )
    }

    func colorRangePreviewImage(
        targetColor: NSColor,
        tolerance: CGFloat,
        inverted: Bool
    ) -> NSImage {
        colorRangePreviewImage(
            targetColors: [targetColor],
            excludedColors: [],
            tolerance: tolerance,
            inverted: inverted
        )
    }

    func colorRangePreviewImage(
        targetColors: [NSColor],
        excludedColors: [NSColor],
        tolerance: CGFloat,
        inverted: Bool
    ) -> NSImage {
        guard let selection = colorRangeSelection(
            targetColors: targetColors,
            excludedColors: excludedColors,
            tolerance: tolerance,
            canvasSize: size,
            inverted: inverted
        ),
              let mask = selection.rasterMask
        else {
            return NSImage.binaryMaskPreviewImage(
                width: max(1, Int(size.width.rounded())),
                height: max(1, Int(size.height.rounded())),
                alpha: []
            ) ?? NSImage(size: size)
        }

        return NSImage.binaryMaskPreviewImage(
            width: mask.width,
            height: mask.height,
            alpha: mask.alpha
        ) ?? NSImage(size: size)
    }

    func grownColorSelection(
        from selection: ImageEditorSelection,
        tolerance: CGFloat,
        canvasSize: CGSize
    ) -> ImageEditorSelection? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = max(1, cgImage.width)
        let height = max(1, cgImage.height)
        guard let canvasMask = selection.rasterizedMask(canvasSize: canvasSize),
              let maskImage = NSImage.selectionMaskImage(
                canvasMask,
                inverted: false,
                targetSize: CGSize(width: width, height: height)
              ),
              let sourceMask = maskImage.selectionAlphaPlaneMask(width: width, height: height),
              sourceMask.width == width,
              sourceMask.height == height,
              sourceMask.alpha.count == width * height
        else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let clampedTolerance = max(0, min(1, tolerance))
        let targets = colorRangeSamples(from: sourceMask, pixels: pixels, bytesPerRow: bytesPerRow)
        guard !targets.isEmpty else { return nil }

        var output = sourceMask.alpha.map { $0 > 0 ? UInt8.max : 0 }
        var queue: [Int] = output.indices.filter { output[$0] > 0 }
        var readIndex = 0

        while readIndex < queue.count {
            let index = queue[readIndex]
            readIndex += 1
            let x = index % width
            let y = index / width

            for neighbor in neighboringPixelIndexes(x: x, y: y, width: width, height: height) {
                guard output[neighbor] == 0 else { continue }
                guard pixelMatchesColorRange(
                    index: neighbor,
                    pixels: pixels,
                    bytesPerRow: bytesPerRow,
                    width: width,
                    targets: targets,
                    tolerance: clampedTolerance
                ) else { continue }
                output[neighbor] = UInt8.max
                queue.append(neighbor)
            }
        }

        guard let outputMask = ImageEditorSelectionMask(width: width, height: height, alpha: output)
            .combined(with: sourceMask, mode: .add),
              let bounds = outputMask.selectedBounds(in: canvasSize)
        else { return nil }

        return .raster(mask: outputMask, bounds: bounds)
    }

    static func binaryMaskPreviewImage(width: Int, height: Int, alpha: [UInt8]) -> NSImage? {
        let width = max(1, width)
        let height = max(1, height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        for y in 0..<height {
            for x in 0..<width {
                let alphaIndex = y * width + x
                let isSelected = alpha.indices.contains(alphaIndex) && alpha[alphaIndex] > 0
                let value: UInt8 = isSelected ? UInt8.max : 0
                let pixelOffset = y * bytesPerRow + x * bytesPerPixel
                pixels[pixelOffset] = value
                pixels[pixelOffset + 1] = value
                pixels[pixelOffset + 2] = value
                pixels[pixelOffset + 3] = UInt8.max
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
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

        let image = NSImage(size: CGSize(width: width, height: height))
        image.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
        return image
    }

    private func colorRangeSamples(
        from mask: ImageEditorSelectionMask,
        pixels: [UInt8],
        bytesPerRow: Int
    ) -> [NSColor] {
        let maxSamples = 48
        let selectedPixelCount = mask.alpha.reduce(0) { count, value in
            value > 0 ? count + 1 : count
        }
        guard selectedPixelCount > 0 else { return [] }

        let interval = max(1, selectedPixelCount / maxSamples)
        var selectedIndex = 0
        var colors: [NSColor] = []
        for y in 0..<mask.height {
            for x in 0..<mask.width {
                guard mask.alpha[y * mask.width + x] > 0 else { continue }
                defer { selectedIndex += 1 }
                guard selectedIndex % interval == 0 else { continue }
                let pixelOffset = y * bytesPerRow + x * 4
                guard pixels[pixelOffset + 3] > 8 else { continue }
                let components = [
                    CGFloat(pixels[pixelOffset]) / 255,
                    CGFloat(pixels[pixelOffset + 1]) / 255,
                    CGFloat(pixels[pixelOffset + 2]) / 255,
                    CGFloat(1)
                ]
                colors.appendUniqueColorRangeSample(
                    NSColor(colorSpace: .deviceRGB, components: components, count: components.count)
                )
                if colors.count >= maxSamples {
                    return colors
                }
            }
        }
        return colors
    }

    private func neighboringPixelIndexes(x: Int, y: Int, width: Int, height: Int) -> [Int] {
        var indexes: [Int] = []
        if x > 0 { indexes.append(y * width + x - 1) }
        if x + 1 < width { indexes.append(y * width + x + 1) }
        if y > 0 { indexes.append((y - 1) * width + x) }
        if y + 1 < height { indexes.append((y + 1) * width + x) }
        return indexes
    }

    private func pixelMatchesColorRange(
        index: Int,
        pixels: [UInt8],
        bytesPerRow: Int,
        width: Int,
        targets: [NSColor],
        tolerance: CGFloat
    ) -> Bool {
        let x = index % width
        let y = index / width
        let pixelOffset = y * bytesPerRow + x * 4
        guard pixels[pixelOffset + 3] > 8 else { return false }
        return targets.containsColorRangeMatch(
            red: CGFloat(pixels[pixelOffset]) / 255,
            green: CGFloat(pixels[pixelOffset + 1]) / 255,
            blue: CGFloat(pixels[pixelOffset + 2]) / 255,
            tolerance: tolerance
        )
    }

    private func selectionAlphaPlaneMask(width: Int, height: Int) -> ImageEditorSelectionMask? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                alpha[y * width + x] = pixels[offset + 3]
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }

    func alphaSelection(threshold: UInt8) -> ImageEditorSelection? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = max(1, cgImage.width)
        let height = max(1, cgImage.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var alpha = [UInt8](repeating: 0, count: width * height)
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = y * bytesPerRow + x * bytesPerPixel
                let value = pixels[pixelOffset + 3]
                let selected = value > threshold ? UInt8.max : 0
                alpha[y * width + x] = selected
                guard selected > 0 else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        let scaleX = size.width / CGFloat(width)
        let scaleY = size.height / CGFloat(height)
        let bounds = CGRect(
            x: CGFloat(minX) * scaleX,
            y: CGFloat(minY) * scaleY,
            width: CGFloat(maxX - minX + 1) * scaleX,
            height: CGFloat(maxY - minY + 1) * scaleY
        )
        return .raster(
            mask: ImageEditorSelectionMask(width: width, height: height, alpha: alpha),
            bounds: bounds
        )
    }

    static func selectionMaskImage(
        _ mask: ImageEditorSelectionMask,
        inverted: Bool,
        targetSize: CGSize
    ) -> NSImage? {
        let values = inverted ? mask.alpha.map { UInt8.max - $0 } : mask.alpha
        guard let sourceImage = NSImage.alphaMaskImage(width: mask.width, height: mask.height, alpha: values) else {
            return nil
        }
        guard sourceImage.size == targetSize else {
            return NSImage.rendered(size: targetSize) { _ in
                sourceImage.draw(
                    in: CGRect(origin: .zero, size: targetSize),
                    from: CGRect(origin: .zero, size: sourceImage.size),
                    operation: .copy,
                    fraction: 1
                )
            }
        }
        return sourceImage
    }

    static func alphaMaskImage(width: Int, height: Int, alpha: [UInt8]) -> NSImage? {
        let width = max(1, width)
        let height = max(1, height)
        guard alpha.count == width * height else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        for y in 0..<height {
            for x in 0..<width {
                let alphaValue = alpha[y * width + x]
                let offset = y * bytesPerRow + x * bytesPerPixel
                // The CGImage is declared premultiplied RGBA, so white must be
                // multiplied by the mask alpha. Supplying 255 RGB with zero or
                // partial alpha is invalid premultiplied data and CoreGraphics
                // may normalize it differently while resizing or round-tripping.
                pixels[offset] = alphaValue
                pixels[offset + 1] = alphaValue
                pixels[offset + 2] = alphaValue
                pixels[offset + 3] = alphaValue
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
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

        let image = NSImage(size: CGSize(width: width, height: height))
        image.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
        return image
    }
}
