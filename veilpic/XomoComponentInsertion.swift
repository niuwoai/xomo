//
//  XomoComponentInsertion.swift
//  veilpic
//

import AppKit
import Foundation

private enum XomoButtonComponentStyle {
    static let minimumWidth: CGFloat = 160
    static let maximumWidth: CGFloat = 240
    static let widthRatio: CGFloat = 0.18
    static let height: CGFloat = 44
    static let labelFontSize: CGFloat = 15
    static let fillColor = NSColor(deviceRed: 0.20, green: 0.48, blue: 0.95, alpha: 1)
    static let strokeColor = NSColor(deviceRed: 0.16, green: 0.39, blue: 0.78, alpha: 1)
    static let strokeWidth: CGFloat = 1
}

enum XomoComponentKind: String, CaseIterable, Identifiable {
    case button

    var id: String { rawValue }

    var title: String {
        L10n.text("xomo.component.\(rawValue).title")
    }
}

extension ImageEditorViewModel {
    func insertXomoComponent(_ component: XomoComponentKind, at proposedOrigin: CGPoint? = nil) {
        switch component {
        case .button:
            insertXomoButton(at: proposedOrigin)
        }
    }

    private func insertXomoButton(at proposedOrigin: CGPoint?) {
        let canvasSize = document.canvasSize
        let buttonSize = CGSize(
            width: min(
                XomoButtonComponentStyle.maximumWidth,
                max(XomoButtonComponentStyle.minimumWidth, canvasSize.width * XomoButtonComponentStyle.widthRatio)
            ),
            height: XomoButtonComponentStyle.height
        )
        let defaultOrigin = CGPoint(
            x: (canvasSize.width - buttonSize.width) * 0.5,
            y: (canvasSize.height - buttonSize.height) * 0.5
        )
        let origin = clampedComponentOrigin(proposedOrigin ?? defaultOrigin, componentSize: buttonSize)
        let buttonFrame = CGRect(origin: origin, size: buttonSize)
        let label = L10n.text("xomo.component.button.defaultLabel")
        let labelContent = ImageEditorTextContent(
            text: label,
            color: .white,
            fontSize: XomoButtonComponentStyle.labelFontSize,
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            isBold: true,
            alignment: .center
        )
        let labelSize = labelContent.layerSize()
        let labelOrigin = CGPoint(
            x: buttonFrame.midX - labelSize.width * 0.5,
            y: buttonFrame.midY - labelSize.height * 0.5
        )

        pushUndo()
        var group = ImageEditorLayer.group(name: L10n.text("xomo.component.button.title"), size: canvasSize)
        group.blendMode = .passThrough

        var background = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.button.backgroundLayer"),
            frame: buttonFrame,
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: XomoButtonComponentStyle.fillColor,
                fillOpacity: 1,
                strokeColor: XomoButtonComponentStyle.strokeColor,
                strokeWidth: XomoButtonComponentStyle.strokeWidth,
                strokeOpacity: 1
            )
        )
        background.groupID = group.id

        var text = ImageEditorLayer.text(
            name: L10n.format("imageEditor.layer.textName", label),
            origin: labelOrigin,
            content: labelContent
        )
        text.groupID = group.id

        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(contentsOf: [background, text, group], at: insertionIndex)
        document.selectedLayerID = group.id
        document.selectedLayerIDs = [group.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("xomo.component.history.insert"))
        statusText = L10n.format("xomo.component.status.inserted", group.name)
    }

    private func clampedComponentOrigin(_ origin: CGPoint, componentSize: CGSize) -> CGPoint {
        CGPoint(
            x: max(0, min(origin.x, max(0, document.canvasSize.width - componentSize.width))),
            y: max(0, min(origin.y, max(0, document.canvasSize.height - componentSize.height)))
        )
    }
}
