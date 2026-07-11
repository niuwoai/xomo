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

private enum XomoInputComponentStyle {
    static let minimumWidth: CGFloat = 220
    static let maximumWidth: CGFloat = 320
    static let widthRatio: CGFloat = 0.26
    static let height: CGFloat = 44
    static let labelFontSize: CGFloat = 15
    static let fillColor = NSColor.white
    static let strokeColor = NSColor(deviceWhite: 0.72, alpha: 1)
    static let strokeWidth: CGFloat = 1
    static let textColor = NSColor(deviceWhite: 0.48, alpha: 1)
}

private enum XomoCardComponentStyle {
    static let minimumWidth: CGFloat = 240
    static let maximumWidth: CGFloat = 360
    static let widthRatio: CGFloat = 0.32
    static let height: CGFloat = 168
    static let titleFontSize: CGFloat = 18
    static let bodyFontSize: CGFloat = 14
    static let horizontalInset: CGFloat = 18
    static let titleTopInset: CGFloat = 20
    static let bodyTopInset: CGFloat = 64
    static let fillColor = NSColor(deviceWhite: 0.98, alpha: 1)
    static let strokeColor = NSColor(deviceWhite: 0.80, alpha: 1)
    static let strokeWidth: CGFloat = 1
    static let titleColor = NSColor(deviceWhite: 0.12, alpha: 1)
    static let bodyColor = NSColor(deviceWhite: 0.42, alpha: 1)
}

enum XomoComponentKind: String, CaseIterable, Identifiable {
    case button
    case input
    case card

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
        case .input:
            insertXomoInput(at: proposedOrigin)
        case .card:
            insertXomoCard(at: proposedOrigin)
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

    private func insertXomoInput(at proposedOrigin: CGPoint?) {
        let canvasSize = document.canvasSize
        let inputSize = CGSize(
            width: min(
                XomoInputComponentStyle.maximumWidth,
                max(XomoInputComponentStyle.minimumWidth, canvasSize.width * XomoInputComponentStyle.widthRatio)
            ),
            height: XomoInputComponentStyle.height
        )
        let defaultOrigin = CGPoint(
            x: (canvasSize.width - inputSize.width) * 0.5,
            y: (canvasSize.height - inputSize.height) * 0.5
        )
        let origin = clampedComponentOrigin(proposedOrigin ?? defaultOrigin, componentSize: inputSize)
        let inputFrame = CGRect(origin: origin, size: inputSize)
        let placeholder = L10n.text("xomo.component.input.defaultPlaceholder")
        let placeholderContent = ImageEditorTextContent(
            text: placeholder,
            color: XomoInputComponentStyle.textColor,
            fontSize: XomoInputComponentStyle.labelFontSize,
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            alignment: .left
        )
        let textOrigin = CGPoint(
            x: inputFrame.minX + ImageEditorTextContent.drawingPadding,
            y: inputFrame.midY - placeholderContent.layerSize().height * 0.5
        )

        pushUndo()
        var group = ImageEditorLayer.group(name: L10n.text("xomo.component.input.title"), size: canvasSize)
        group.blendMode = .passThrough

        var background = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.input.backgroundLayer"),
            frame: inputFrame,
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: XomoInputComponentStyle.fillColor,
                fillOpacity: 1,
                strokeColor: XomoInputComponentStyle.strokeColor,
                strokeWidth: XomoInputComponentStyle.strokeWidth,
                strokeOpacity: 1
            )
        )
        background.groupID = group.id

        var text = ImageEditorLayer.text(
            name: L10n.format("imageEditor.layer.textName", placeholder),
            origin: textOrigin,
            content: placeholderContent
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

    private func insertXomoCard(at proposedOrigin: CGPoint?) {
        let canvasSize = document.canvasSize
        let cardSize = CGSize(
            width: min(
                XomoCardComponentStyle.maximumWidth,
                max(XomoCardComponentStyle.minimumWidth, canvasSize.width * XomoCardComponentStyle.widthRatio)
            ),
            height: XomoCardComponentStyle.height
        )
        let defaultOrigin = CGPoint(
            x: (canvasSize.width - cardSize.width) * 0.5,
            y: (canvasSize.height - cardSize.height) * 0.5
        )
        let origin = clampedComponentOrigin(proposedOrigin ?? defaultOrigin, componentSize: cardSize)
        let cardFrame = CGRect(origin: origin, size: cardSize)
        let title = L10n.text("xomo.component.card.defaultTitle")
        let body = L10n.text("xomo.component.card.defaultBody")
        let titleContent = ImageEditorTextContent(
            text: title,
            color: XomoCardComponentStyle.titleColor,
            fontSize: XomoCardComponentStyle.titleFontSize,
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            isBold: true,
            alignment: .left
        )
        let bodyContent = ImageEditorTextContent(
            text: body,
            color: XomoCardComponentStyle.bodyColor,
            fontSize: XomoCardComponentStyle.bodyFontSize,
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            alignment: .left
        )

        pushUndo()
        var group = ImageEditorLayer.group(name: L10n.text("xomo.component.card.title"), size: canvasSize)
        group.blendMode = .passThrough

        var background = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.card.backgroundLayer"),
            frame: cardFrame,
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: XomoCardComponentStyle.fillColor,
                fillOpacity: 1,
                strokeColor: XomoCardComponentStyle.strokeColor,
                strokeWidth: XomoCardComponentStyle.strokeWidth,
                strokeOpacity: 1
            )
        )
        background.groupID = group.id

        var titleLayer = ImageEditorLayer.text(
            name: L10n.format("imageEditor.layer.textName", title),
            origin: CGPoint(x: cardFrame.minX + XomoCardComponentStyle.horizontalInset, y: cardFrame.minY + XomoCardComponentStyle.titleTopInset),
            content: titleContent
        )
        titleLayer.groupID = group.id

        var bodyLayer = ImageEditorLayer.text(
            name: L10n.format("imageEditor.layer.textName", body),
            origin: CGPoint(x: cardFrame.minX + XomoCardComponentStyle.horizontalInset, y: cardFrame.minY + XomoCardComponentStyle.bodyTopInset),
            content: bodyContent
        )
        bodyLayer.groupID = group.id

        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(contentsOf: [background, bodyLayer, titleLayer, group], at: insertionIndex)
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
