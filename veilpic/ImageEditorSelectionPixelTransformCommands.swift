import AppKit

enum ImageEditorSelectionScaleAnchor: Int, CaseIterable {
    case topLeft
    case topCenter
    case topRight
    case centerLeft
    case center
    case centerRight
    case bottomLeft
    case bottomCenter
    case bottomRight

    var unitPoint: CGPoint {
        CGPoint(x: CGFloat(rawValue % 3) / 2, y: CGFloat(rawValue / 3) / 2)
    }

    var titleKey: String {
        switch self {
        case .topLeft: "imageEditor.dialog.selectionScaleAnchorTopLeft"
        case .topCenter: "imageEditor.dialog.selectionScaleAnchorTopCenter"
        case .topRight: "imageEditor.dialog.selectionScaleAnchorTopRight"
        case .centerLeft: "imageEditor.dialog.selectionScaleAnchorCenterLeft"
        case .center: "imageEditor.dialog.selectionScaleAnchorCenter"
        case .centerRight: "imageEditor.dialog.selectionScaleAnchorCenterRight"
        case .bottomLeft: "imageEditor.dialog.selectionScaleAnchorBottomLeft"
        case .bottomCenter: "imageEditor.dialog.selectionScaleAnchorBottomCenter"
        case .bottomRight: "imageEditor.dialog.selectionScaleAnchorBottomRight"
        }
    }
}

enum ImageEditorScalePercentage {
    static let allowedRange = 1.0...1_000.0

    static func parse(_ text: String, locale: Locale = .current) -> Double? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasSuffix("%") {
            value.removeLast()
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !value.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = locale
        let separator = formatter.decimalSeparator ?? "."
        var normalized = ""
        var foundDecimalSeparator = false
        for character in value {
            if let scalar = character.unicodeScalars.first,
               character.unicodeScalars.count == 1,
               scalar.value >= 48, scalar.value <= 57 {
                normalized.unicodeScalars.append(scalar)
            } else if String(character) == separator, !foundDecimalSeparator {
                normalized.append(".")
                foundDecimalSeparator = true
            } else {
                return nil
            }
        }

        guard let percentage = Double(normalized), percentage.isFinite,
              allowedRange.contains(percentage)
        else { return nil }
        return percentage
    }

    static func isValid(_ percentage: Double) -> Bool {
        percentage.isFinite && allowedRange.contains(percentage)
    }

    static func formatted(_ percentage: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return "\(formatter.string(from: NSNumber(value: percentage)) ?? String(percentage))%"
    }
}

extension ImageEditorViewModel {
    var canScaleSelectedPixels: Bool {
        canFlipSelectedPixels
    }

    var canFlipSelectedPixels: Bool {
        guard !isQuickMaskMode,
              !isEditingLayerMask,
              feather.isFinite,
              let selection = document.selection
        else { return false }

        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        guard !selectedIDs.isEmpty else { return false }
        let selectedIndices = document.layers.indices.filter { selectedIDs.contains(document.layers[$0].id) }
        guard selectedIndices.count == selectedIDs.count else { return false }
        return selectedIndices.allSatisfy { index in
            let layer = document.layers[index]
            return layer.kind.isPixel
                && !document.isEffectivelyPixelsLocked(layer)
                && !document.isEffectivelyTransparencyLocked(layer)
                && selection.mayAffect(
                    layerFrame: layer.frame,
                    canvasSize: document.canvasSize,
                    expansion: feather
                )
        }
    }

    var canRotateSelectedPixelsQuarterTurn: Bool {
        guard canFlipSelectedPixels else { return false }
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        let selectedLayers = document.layers.filter { selectedIDs.contains($0.id) }
        guard !selectedLayers.isEmpty else { return false }
        return selectedLayers.allSatisfy { layer in
            let scaleX = layer.frame.width / max(layer.image.size.width, 1)
            let scaleY = layer.frame.height / max(layer.image.size.height, 1)
            return scaleX.isFinite && scaleY.isFinite && abs(scaleX - scaleY) < 0.0001
        }
    }

    func flipSelectedPixelsHorizontally() {
        flipSelectedPixels(horizontally: true)
    }

    func flipSelectedPixelsVertically() {
        flipSelectedPixels(horizontally: false)
    }

    func rotateSelectedPixelsClockwise() {
        rotateSelectedPixels(clockwiseTurns: 1)
    }

    func rotateSelectedPixelsCounterclockwise() {
        rotateSelectedPixels(clockwiseTurns: -1)
    }

    func rotateSelectedPixels180() {
        rotateSelectedPixels(clockwiseTurns: 2)
    }

    func scaleSelectedPixelsUp() {
        scaleSelectedPixels(
            by: 2,
            historyKey: "imageEditor.history.selectionPixelsScaleUp",
            statusKey: "imageEditor.status.selectionPixelsScaledUp"
        )
    }

    func scaleSelectedPixelsDown() {
        scaleSelectedPixels(
            by: 0.5,
            historyKey: "imageEditor.history.selectionPixelsScaleDown",
            statusKey: "imageEditor.status.selectionPixelsScaledDown"
        )
    }

    func scaleSelectedPixels(
        toPercent percentage: Double,
        anchor: ImageEditorSelectionScaleAnchor = .center
    ) {
        guard canScaleSelectedPixels else { return }
        guard ImageEditorScalePercentage.isValid(percentage) else {
            statusText = L10n.text("imageEditor.status.selectionPixelScaleInvalid")
            return
        }

        let formattedPercentage = ImageEditorScalePercentage.formatted(percentage)
        let historyTitle: String
        let statusText: String
        if anchor == .center {
            historyTitle = L10n.format("imageEditor.history.selectionPixelsScaleCustom", formattedPercentage)
            statusText = L10n.format("imageEditor.status.selectionPixelsScaleCustom", formattedPercentage)
        } else {
            let anchorTitle = L10n.text(anchor.titleKey)
            historyTitle = L10n.format(
                "imageEditor.history.selectionPixelsScaleCustomAtAnchor", formattedPercentage, anchorTitle
            )
            statusText = L10n.format(
                "imageEditor.status.selectionPixelsScaleCustomAtAnchor", formattedPercentage, anchorTitle
            )
        }
        scaleSelectedPixels(
            by: CGFloat(percentage / 100),
            anchor: anchor,
            historyTitle: historyTitle,
            statusText: statusText
        )
    }

    func presentSelectedPixelScaleDialog() {
        guard canScaleSelectedPixels else { return }

        let alert = NSAlert()
        alert.messageText = L10n.text("imageEditor.dialog.selectionPixelScaleTitle")
        alert.informativeText = L10n.text("imageEditor.dialog.selectionPixelScaleMessage")
        let percentageField = NSTextField(string: "100")
        percentageField.frame = CGRect(x: 0, y: 0, width: 240, height: 24)
        percentageField.setAccessibilityIdentifier("image-editor-selection-pixel-scale-percentage")
        let anchorPicker = NSPopUpButton(frame: CGRect(x: 0, y: 0, width: 240, height: 26), pullsDown: false)
        for anchor in ImageEditorSelectionScaleAnchor.allCases {
            anchorPicker.addItem(withTitle: L10n.text(anchor.titleKey))
            anchorPicker.lastItem?.tag = anchor.rawValue
        }
        anchorPicker.selectItem(withTag: ImageEditorSelectionScaleAnchor.center.rawValue)
        anchorPicker.setAccessibilityIdentifier("image-editor-selection-pixel-scale-anchor")
        let accessoryStack = NSStackView(views: [
            scaleDialogRow(
                label: L10n.text("imageEditor.dialog.selectionPixelScalePercentage"),
                control: percentageField
            ),
            scaleDialogRow(
                label: L10n.text("imageEditor.dialog.selectionPixelScaleAnchor"),
                control: anchorPicker
            )
        ])
        accessoryStack.orientation = .vertical
        accessoryStack.alignment = .leading
        accessoryStack.spacing = 8
        accessoryStack.setFrameSize(accessoryStack.fittingSize)
        alert.accessoryView = accessoryStack
        alert.addButton(withTitle: L10n.text("imageEditor.action.selectionPixelScaleApply"))
        alert.addButton(withTitle: L10n.text("button.cancel"))
        alert.window.initialFirstResponder = percentageField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let percentage = ImageEditorScalePercentage.parse(percentageField.stringValue) else {
            statusText = L10n.text("imageEditor.status.selectionPixelScaleInvalid")
            return
        }
        let anchor = ImageEditorSelectionScaleAnchor(rawValue: anchorPicker.selectedTag()) ?? .center
        scaleSelectedPixels(toPercent: percentage, anchor: anchor)
    }

    private func scaleDialogRow(label: String, control: NSView) -> NSStackView {
        let row = NSStackView(views: [NSTextField(labelWithString: label), control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func flipSelectedPixels(horizontally: Bool) {
        guard canFlipSelectedPixels else { return }
        finishActiveCanvasEditForNewCommand()
        guard let selection = document.selection,
              let flippedSelection = selection.flipped(horizontal: horizontally, canvasSize: document.canvasSize)
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let selectionCoverageChanged: Bool
        if let originalMask = selection.rasterizedMask(canvasSize: document.canvasSize),
           let transformedMask = flippedSelection.rasterizedMask(canvasSize: document.canvasSize) {
            selectionCoverageChanged = originalMask != transformedMask
        } else {
            selectionCoverageChanged = flippedSelection != selection
        }
        let committedSelection = selectionCoverageChanged ? flippedSelection : selection

        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        let selectedIndices = document.layers.indices.filter { selectedIDs.contains(document.layers[$0].id) }
        var updatedLayers = document.layers
        var pixelDataChanged = false

        for index in selectedIndices {
            guard let result = flippedLayer(
                document.layers[index], selection: selection, horizontally: horizontally
            ) else {
                statusText = L10n.text("imageEditor.status.operationFailed")
                return
            }
            if result.pixelDataChanged {
                pixelDataChanged = true
                updatedLayers[index] = result.layer
            }
        }

        guard pixelDataChanged || selectionCoverageChanged else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        var updatedDocument = document
        updatedDocument.layers = updatedLayers
        updatedDocument.selection = committedSelection
        pushUndo()
        document = updatedDocument

        let historyKey = horizontally
            ? "imageEditor.history.selectionPixelsFlipHorizontal"
            : "imageEditor.history.selectionPixelsFlipVertical"
        let statusKey = horizontally
            ? "imageEditor.status.selectionPixelsFlippedHorizontal"
            : "imageEditor.status.selectionPixelsFlippedVertical"
        appendHistory(L10n.text(historyKey))
        statusText = L10n.text(statusKey)
    }

    private func rotateSelectedPixels(clockwiseTurns: Int) {
        guard clockwiseTurns.isMultiple(of: 2) ? canFlipSelectedPixels : canRotateSelectedPixelsQuarterTurn else { return }
        finishActiveCanvasEditForNewCommand()
        guard let selection = document.selection,
              let rotatedSelection = selection.rotatedQuarterTurns(
                clockwiseTurns: clockwiseTurns,
                canvasSize: document.canvasSize
              )
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let selectionCoverageChanged: Bool
        if let originalMask = selection.rasterizedMask(canvasSize: document.canvasSize),
           let transformedMask = rotatedSelection.rasterizedMask(canvasSize: document.canvasSize) {
            selectionCoverageChanged = originalMask != transformedMask
        } else {
            selectionCoverageChanged = rotatedSelection != selection
        }
        let committedSelection = selectionCoverageChanged ? rotatedSelection : selection

        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        let selectedIndices = document.layers.indices.filter { selectedIDs.contains(document.layers[$0].id) }
        var updatedLayers = document.layers
        var pixelDataChanged = false

        for index in selectedIndices {
            guard let result = rotatedLayer(
                document.layers[index], selection: selection, destinationSelection: rotatedSelection,
                clockwiseTurns: clockwiseTurns
            ) else {
                statusText = L10n.text("imageEditor.status.operationFailed")
                return
            }
            if result.pixelDataChanged {
                pixelDataChanged = true
                updatedLayers[index] = result.layer
            }
        }

        guard pixelDataChanged || selectionCoverageChanged else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        var updatedDocument = document
        updatedDocument.layers = updatedLayers
        updatedDocument.selection = committedSelection
        pushUndo()
        document = updatedDocument

        let normalizedTurns = ((clockwiseTurns % 4) + 4) % 4
        let historyKey: String
        let statusKey: String
        switch normalizedTurns {
        case 1:
            historyKey = "imageEditor.history.selectionPixelsRotateClockwise"
            statusKey = "imageEditor.status.selectionPixelsRotatedClockwise"
        case 2:
            historyKey = "imageEditor.history.selectionPixelsRotate180"
            statusKey = "imageEditor.status.selectionPixelsRotated180"
        default:
            historyKey = "imageEditor.history.selectionPixelsRotateCounterclockwise"
            statusKey = "imageEditor.status.selectionPixelsRotatedCounterclockwise"
        }
        appendHistory(L10n.text(historyKey))
        statusText = L10n.text(statusKey)
    }

    private func scaleSelectedPixels(by factor: CGFloat, historyKey: String, statusKey: String) {
        scaleSelectedPixels(
            by: factor,
            historyTitle: L10n.text(historyKey),
            statusText: L10n.text(statusKey)
        )
    }

    private func scaleSelectedPixels(
        by factor: CGFloat,
        anchor: ImageEditorSelectionScaleAnchor = .center,
        historyTitle: String,
        statusText: String
    ) {
        guard canScaleSelectedPixels, factor.isFinite, factor > 0 else { return }
        finishActiveCanvasEditForNewCommand()
        guard let selection = document.selection,
              let scaling = selection.scaledWithGeometry(
                by: factor,
                canvasSize: document.canvasSize,
                anchor: anchor
              )
        else {
            self.statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let scaledSelection = scaling.selection

        let selectionCoverageChanged: Bool
        if let originalMask = selection.rasterizedMask(canvasSize: document.canvasSize),
           let transformedMask = scaledSelection.rasterizedMask(canvasSize: document.canvasSize) {
            selectionCoverageChanged = originalMask != transformedMask
        } else {
            selectionCoverageChanged = scaledSelection != selection
        }

        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : Set(document.selectedLayerIDs)
        let selectedIndices = document.layers.indices.filter { selectedIDs.contains(document.layers[$0].id) }
        var updatedLayers = document.layers
        var pixelDataChanged = false
        for index in selectedIndices {
            guard let result = scaledLayer(
                document.layers[index],
                selection: selection,
                sourceCanvasBounds: scaling.sourceCanvasBounds,
                destinationCanvasBounds: scaling.destinationCanvasBounds
            ) else {
                self.statusText = L10n.text("imageEditor.status.operationFailed")
                return
            }
            if result.pixelDataChanged {
                pixelDataChanged = true
                updatedLayers[index] = result.layer
            }
        }

        guard pixelDataChanged || selectionCoverageChanged else {
            self.statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }
        var updatedDocument = document
        updatedDocument.layers = updatedLayers
        updatedDocument.selection = selectionCoverageChanged ? scaledSelection : selection
        pushUndo()
        document = updatedDocument
        appendHistory(historyTitle)
        self.statusText = statusText
    }

    private func flippedLayer(
        _ layer: ImageEditorLayer, selection: ImageEditorSelection, horizontally: Bool
    ) -> (layer: ImageEditorLayer, pixelDataChanged: Bool)? {
        guard let backingLayer = layer.expandedPixelSelectionTransformBacking(
            selection: selection, canvasSize: document.canvasSize, feather: feather
        ) else { return nil }
        let width = Int(backingLayer.image.size.width.rounded())
        let height = Int(backingLayer.image.size.height.rounded())
        guard let maskImage = selection.layerMask(
            layerFrame: backingLayer.frame,
            layerSize: backingLayer.image.size,
            canvasSize: document.canvasSize,
            feather: feather,
            usesNearestSampling: true
        ), let mask = ImageEditorPixelMoveMaskAlpha.read(from: maskImage, width: width, height: height),
           let source = ImageEditorRGBAImage.pixels(from: backingLayer.image, width: width, height: height),
           let output = ImageEditorPixelSelectionTransform.flipped(
               source: source, maskAlpha: mask, width: width, height: height, horizontally: horizontally
           ), let image = ImageEditorRGBAImage.image(
               width: width, height: height, pixels: output, size: backingLayer.image.size
           )
        else { return nil }

        var result = backingLayer
        result.image = image
        return (result, source != output)
    }

    private func rotatedLayer(
        _ layer: ImageEditorLayer,
        selection: ImageEditorSelection,
        destinationSelection: ImageEditorSelection,
        clockwiseTurns: Int
    ) -> (layer: ImageEditorLayer, pixelDataChanged: Bool)? {
        guard let backingLayer = layer.expandedPixelSelectionTransformBacking(
            selection: selection,
            destinationSelection: destinationSelection,
            canvasSize: document.canvasSize,
            feather: feather
        ) else { return nil }
        let width = Int(backingLayer.image.size.width.rounded())
        let height = Int(backingLayer.image.size.height.rounded())
        guard let maskImage = selection.layerMask(
            layerFrame: backingLayer.frame,
            layerSize: backingLayer.image.size,
            canvasSize: document.canvasSize,
            feather: feather,
            usesNearestSampling: true
        ), let mask = ImageEditorPixelMoveMaskAlpha.read(from: maskImage, width: width, height: height),
           let source = ImageEditorRGBAImage.pixels(from: backingLayer.image, width: width, height: height),
           let output = ImageEditorPixelSelectionTransform.rotatedQuarterTurns(
               source: source, maskAlpha: mask, width: width, height: height, clockwiseTurns: clockwiseTurns
           ), let image = ImageEditorRGBAImage.image(
               width: width, height: height, pixels: output, size: backingLayer.image.size
           )
        else { return nil }

        var result = backingLayer
        result.image = image
        return (result, source != output)
    }

    private func scaledLayer(
        _ layer: ImageEditorLayer,
        selection: ImageEditorSelection,
        sourceCanvasBounds: CGRect,
        destinationCanvasBounds: CGRect
    ) -> (layer: ImageEditorLayer, pixelDataChanged: Bool)? {
        guard let backingLayer = layer.expandedPixelSelectionTransformBacking(
            selection: selection,
            destinationCanvasBounds: destinationCanvasBounds,
            canvasSize: document.canvasSize,
            feather: feather
        ) else { return nil }
        let width = Int(backingLayer.image.size.width.rounded())
        let height = Int(backingLayer.image.size.height.rounded())
        guard let sourceMaskImage = selection.layerMask(
            layerFrame: backingLayer.frame,
            layerSize: backingLayer.image.size,
            canvasSize: document.canvasSize,
            feather: feather,
            usesNearestSampling: true
        ), let sourceMask = ImageEditorPixelMoveMaskAlpha.read(
            from: sourceMaskImage, width: width, height: height
        ), let destinationMask = ImageEditorPixelSelectionTransform.scaledCoverageMask(
            sourceMaskAlpha: sourceMask,
            width: width,
            height: height,
            layerFrame: backingLayer.frame,
            sourceCanvasBounds: sourceCanvasBounds,
            destinationCanvasBounds: destinationCanvasBounds,
            coverageCanvasBounds: feather > 0
                ? destinationCanvasBounds.insetBy(dx: -feather * 3, dy: -feather * 3)
                : destinationCanvasBounds,
            usesNearestSampling: feather <= 0
        ), let source = ImageEditorRGBAImage.pixels(
            from: backingLayer.image, width: width, height: height
        ), let output = ImageEditorPixelSelectionTransform.scaled(
            source: source,
            sourceMaskAlpha: sourceMask,
            destinationMaskAlpha: destinationMask,
            width: width,
            height: height,
            layerFrame: backingLayer.frame,
            sourceCanvasBounds: sourceCanvasBounds,
            destinationCanvasBounds: destinationCanvasBounds
        ), let image = ImageEditorRGBAImage.image(
            width: width, height: height, pixels: output, size: backingLayer.image.size
        ) else { return nil }

        var result = backingLayer
        result.image = image
        return (result, source != output)
    }
}
