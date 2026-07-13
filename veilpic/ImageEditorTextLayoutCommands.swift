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
}
