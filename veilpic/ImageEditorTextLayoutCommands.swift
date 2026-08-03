//
//  ImageEditorTextLayoutCommands.swift
//  veilpic
//
//  Created by Codex on 2026/7/13.
//

import AppKit
import Foundation

enum ImageEditorTextLayoutMode: String, CaseIterable, Identifiable {
    case point
    case paragraph

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.textLayoutMode.\(rawValue)")
    }
}

enum ImageEditorTextBoxFitMode: String, CaseIterable {
    case fitContent
    case expandHeight
}

extension ImageEditorTextContent {
    var layoutMode: ImageEditorTextLayoutMode {
        boxWidth > 0 ? .paragraph : .point
    }

    func widthForParagraphConversion() -> CGFloat {
        let size = layerSize()
        return max(1, drawingRect(in: size).width)
    }
}

extension ImageEditorViewModel {
    var selectedTextBoxHasOverflow: Bool {
        guard document.selectedLayerIDs.count == 1,
              let layer = document.selectedLayer,
              let content = layer.textContent,
              content.layoutMode == .paragraph
        else { return false }
        return content.hasOverflow
    }

    var canConvertSelectedTextToPoint: Bool {
        canConvertSelectedText(to: .point)
    }

    var canConvertSelectedTextToParagraph: Bool {
        canConvertSelectedText(to: .paragraph)
    }

    var canFitSelectedTextBoxesToContent: Bool {
        !textBoxFitLayerIndices(for: .fitContent).isEmpty
    }

    var canExpandSelectedTextBoxes: Bool {
        !textBoxFitLayerIndices(for: .expandHeight).isEmpty
    }

    var canSetSelectedTextBoxAutoHeight: Bool {
        !autoHeightTextBoxIndices().isEmpty
    }

    var selectedTextBoxUsesAutoHeight: Bool {
        let indices = autoHeightTextBoxIndices()
        return !indices.isEmpty && indices.allSatisfy {
            document.layers[$0].textContent?.boxHeight == 0
        }
    }

    func convertSelectedTextLayers(to layoutMode: ImageEditorTextLayoutMode) {
        let indices = convertibleSelectedTextLayerIndices(to: layoutMode)
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for index in indices {
            guard var content = document.layers[index].textContent else { continue }
            content.boxWidth = layoutMode == .paragraph ? content.widthForParagraphConversion() : 0
            content.boxHeight = 0
            resizeTextLayer(at: index, for: content)
        }
        if let content = document.selectedLayer?.textContent {
            textBoxWidth = Double(content.boxWidth)
            textBoxHeight = Double(content.boxHeight)
        }
        appendHistory(L10n.text(historyKey(for: layoutMode)))
        statusText = L10n.format(statusKey(for: layoutMode), indices.count)
    }

    func fitSelectedTextBoxes(_ mode: ImageEditorTextBoxFitMode) {
        let indices = textBoxFitLayerIndices(for: mode)
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for index in indices {
            guard var content = document.layers[index].textContent else { continue }
            content.boxHeight = min(
                ImageEditorTextContent.maximumBoxDimension,
                max(1, content.requiredParagraphHeight)
            )
            resizeTextLayer(at: index, for: content)
        }
        if let content = document.selectedLayer?.textContent {
            textBoxWidth = Double(content.boxWidth)
            textBoxHeight = Double(content.boxHeight)
        }
        appendHistory(L10n.text(historyKey(for: mode)))
        statusText = L10n.format(statusKey(for: mode), indices.count)
    }

    func setSelectedTextBoxesAutoHeight(_ enabled: Bool) {
        let indices = autoHeightTextBoxIndices().filter { index in
            guard let content = document.layers[index].textContent else { return false }
            return enabled ? content.boxHeight > 0 : content.boxHeight == 0
        }
        guard !indices.isEmpty else { return }

        pushUndo()
        for index in indices {
            guard var content = document.layers[index].textContent else { continue }
            content.boxHeight = enabled
                ? 0
                : min(ImageEditorTextContent.maximumBoxDimension, max(1, content.requiredParagraphHeight))
            resizeTextLayer(at: index, for: content)
        }
        if let content = document.selectedLayer?.textContent {
            textBoxHeight = Double(content.boxHeight)
        }
        appendHistory(L10n.text(enabled
            ? "imageEditor.history.textBoxAutoHeightEnable"
            : "imageEditor.history.textBoxAutoHeightDisable"))
        statusText = L10n.format(
            enabled
                ? "imageEditor.status.textBoxAutoHeightEnabled"
                : "imageEditor.status.textBoxAutoHeightDisabled",
            indices.count
        )
    }

    private func canConvertSelectedText(to layoutMode: ImageEditorTextLayoutMode) -> Bool {
        !convertibleSelectedTextLayerIndices(to: layoutMode).isEmpty
    }

    private func convertibleSelectedTextLayerIndices(to layoutMode: ImageEditorTextLayoutMode) -> [Int] {
        document.layers.indices.filter { index in
            let layer = document.layers[index]
            guard document.selectedLayerIDs.contains(layer.id),
                  let content = layer.textContent
            else { return false }
            return content.layoutMode != layoutMode && !document.isEffectivelyPixelsLocked(layer)
        }
    }

    private func textBoxFitLayerIndices(for mode: ImageEditorTextBoxFitMode) -> [Int] {
        document.layers.indices.filter { index in
            let layer = document.layers[index]
            guard document.selectedLayerIDs.contains(layer.id),
                  let content = layer.textContent,
                  content.layoutMode == .paragraph,
                  content.boxHeight > 0,
                  !document.isEffectivelyPixelsLocked(layer)
            else { return false }
            let requiredHeight = min(
                ImageEditorTextContent.maximumBoxDimension,
                max(1, content.requiredParagraphHeight)
            )
            switch mode {
            case .fitContent:
                return abs(requiredHeight - content.boxHeight) >= 0.5
            case .expandHeight:
                return requiredHeight > content.boxHeight + 0.5
            }
        }
    }

    private func autoHeightTextBoxIndices() -> [Int] {
        document.layers.indices.filter { index in
            let layer = document.layers[index]
            guard document.selectedLayerIDs.contains(layer.id),
                  let content = layer.textContent
            else { return false }
            return content.layoutMode == .paragraph && !document.isEffectivelyPixelsLocked(layer)
        }
    }

    private func resizeTextLayer(at index: Int, for content: ImageEditorTextContent) {
        let layerSize = content.layerSize()
        if let mask = document.layers[index].mask, mask.size != layerSize {
            document.layers[index].mask = mask.resized(to: layerSize)
        }
        document.layers[index].image = NSImage.transparent(size: layerSize)
        document.layers[index].frame.size = layerSize
        document.layers[index].kind = .text(content)
    }

    private func historyKey(for layoutMode: ImageEditorTextLayoutMode) -> String {
        layoutMode == .paragraph
            ? "imageEditor.history.textConvertToParagraph"
            : "imageEditor.history.textConvertToPoint"
    }

    private func statusKey(for layoutMode: ImageEditorTextLayoutMode) -> String {
        layoutMode == .paragraph
            ? "imageEditor.status.textConvertedToParagraph"
            : "imageEditor.status.textConvertedToPoint"
    }

    private func historyKey(for mode: ImageEditorTextBoxFitMode) -> String {
        mode == .fitContent
            ? "imageEditor.history.textBoxFitContent"
            : "imageEditor.history.textBoxExpandHeight"
    }

    private func statusKey(for mode: ImageEditorTextBoxFitMode) -> String {
        mode == .fitContent
            ? "imageEditor.status.textBoxFitContent"
            : "imageEditor.status.textBoxExpandHeight"
    }
}
