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
    static let strokeWidth: CGFloat = 1
}

private enum XomoButtonVariant: Equatable {
    case primary
    case secondary
    case ghost
    case icon

    var component: XomoComponentKind {
        switch self {
        case .primary: .button
        case .secondary: .secondaryButton
        case .ghost: .ghostButton
        case .icon: .iconButton
        }
    }

    var size: CGSize? {
        switch self {
        case .icon:
            CGSize(width: XomoButtonComponentStyle.height, height: XomoButtonComponentStyle.height)
        case .primary, .secondary, .ghost:
            nil
        }
    }

    var fillColor: NSColor {
        switch self {
        case .primary, .icon:
            NSColor(deviceRed: 0.20, green: 0.48, blue: 0.95, alpha: 1)
        case .secondary:
            .white
        case .ghost:
            .clear
        }
    }

    var fillOpacity: CGFloat {
        self == .ghost ? 0 : 1
    }

    var strokeColor: NSColor {
        switch self {
        case .primary, .icon:
            NSColor(deviceRed: 0.16, green: 0.39, blue: 0.78, alpha: 1)
        case .secondary, .ghost:
            NSColor(deviceRed: 0.20, green: 0.48, blue: 0.95, alpha: 1)
        }
    }

    var strokeOpacity: CGFloat {
        self == .ghost ? 0 : 1
    }

    var labelColor: NSColor {
        switch self {
        case .primary, .icon:
            .white
        case .secondary, .ghost:
            NSColor(deviceRed: 0.20, green: 0.48, blue: 0.95, alpha: 1)
        }
    }
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

private enum XomoImageComponentStyle {
    static let minimumWidth: CGFloat = 240
    static let maximumWidth: CGFloat = 360
    static let widthRatio: CGFloat = 0.32
    static let aspectRatio: CGFloat = 16 / 10
}

private enum XomoAvatarComponentStyle {
    static let diameter: CGFloat = 96
    static let labelFontSize: CGFloat = 32
    static let fillColor = NSColor(deviceRed: 0.20, green: 0.48, blue: 0.95, alpha: 1)
    static let strokeColor = NSColor(deviceRed: 0.16, green: 0.39, blue: 0.78, alpha: 1)
    static let strokeWidth: CGFloat = 1
}

private enum XomoIconComponentStyle {
    static let size: CGFloat = 64
    static let fillColor = NSColor(deviceRed: 0.96, green: 0.65, blue: 0.14, alpha: 1)
    static let strokeColor = NSColor(deviceRed: 0.83, green: 0.49, blue: 0.07, alpha: 1)
    static let strokeWidth: CGFloat = 1
    static let starPoints: [CGPoint] = [
        CGPoint(x: 32, y: 2),
        CGPoint(x: 39, y: 23),
        CGPoint(x: 62, y: 23),
        CGPoint(x: 43, y: 37),
        CGPoint(x: 50, y: 60),
        CGPoint(x: 32, y: 46),
        CGPoint(x: 14, y: 60),
        CGPoint(x: 21, y: 37),
        CGPoint(x: 2, y: 23),
        CGPoint(x: 25, y: 23)
    ]
}

enum XomoComponentKind: String, CaseIterable, Identifiable {
    case button
    case secondaryButton
    case ghostButton
    case iconButton
    case input
    case card
    case image
    case avatar
    case icon

    var id: String { rawValue }

    var title: String {
        L10n.text("xomo.component.\(rawValue).title")
    }
}

extension ImageEditorViewModel {
    func insertXomoComponent(_ component: XomoComponentKind, at proposedOrigin: CGPoint? = nil) {
        switch component {
        case .button:
            insertXomoButton(.primary, at: proposedOrigin)
        case .secondaryButton:
            insertXomoButton(.secondary, at: proposedOrigin)
        case .ghostButton:
            insertXomoButton(.ghost, at: proposedOrigin)
        case .iconButton:
            insertXomoButton(.icon, at: proposedOrigin)
        case .input:
            insertXomoInput(at: proposedOrigin)
        case .card:
            insertXomoCard(at: proposedOrigin)
        case .image:
            insertXomoImage(at: proposedOrigin)
        case .avatar:
            insertXomoAvatar(at: proposedOrigin)
        case .icon:
            insertXomoIcon(at: proposedOrigin)
        }
    }

    private func insertXomoButton(_ variant: XomoButtonVariant, at proposedOrigin: CGPoint?) {
        let canvasSize = document.canvasSize
        let buttonSize = variant.size ?? CGSize(
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
        let component = variant.component
        let label = L10n.text("xomo.component.\(component.rawValue).defaultLabel")
        let labelContent = ImageEditorTextContent(
            text: label,
            color: variant.labelColor,
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
        var group = ImageEditorLayer.group(name: component.title, size: canvasSize)
        group.blendMode = .passThrough

        var background = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.\(component.rawValue).backgroundLayer"),
            frame: buttonFrame,
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: variant.fillColor,
                fillOpacity: variant.fillOpacity,
                strokeColor: variant.strokeColor,
                strokeWidth: XomoButtonComponentStyle.strokeWidth,
                strokeOpacity: variant.strokeOpacity
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

    private func insertXomoImage(at proposedOrigin: CGPoint?) {
        let canvasSize = document.canvasSize
        let width = min(
            XomoImageComponentStyle.maximumWidth,
            max(XomoImageComponentStyle.minimumWidth, canvasSize.width * XomoImageComponentStyle.widthRatio)
        )
        let imageSize = CGSize(width: width, height: width / XomoImageComponentStyle.aspectRatio)
        let defaultOrigin = CGPoint(
            x: (canvasSize.width - imageSize.width) * 0.5,
            y: (canvasSize.height - imageSize.height) * 0.5
        )
        let origin = clampedComponentOrigin(proposedOrigin ?? defaultOrigin, componentSize: imageSize)

        pushUndo()
        var group = ImageEditorLayer.group(name: L10n.text("xomo.component.image.title"), size: canvasSize)
        group.blendMode = .passThrough

        var imageLayer = ImageEditorLayer(
            name: L10n.text("xomo.component.image.placeholderLayer"),
            image: imagePlaceholderImage(size: imageSize),
            mask: nil,
            frame: CGRect(origin: origin, size: imageSize),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false
        )
        imageLayer.groupID = group.id

        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(contentsOf: [imageLayer, group], at: insertionIndex)
        document.selectedLayerID = group.id
        document.selectedLayerIDs = [group.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("xomo.component.history.insert"))
        statusText = L10n.format("xomo.component.status.inserted", group.name)
    }

    private func insertXomoAvatar(at proposedOrigin: CGPoint?) {
        let avatarSize = CGSize(width: XomoAvatarComponentStyle.diameter, height: XomoAvatarComponentStyle.diameter)
        let defaultOrigin = CGPoint(
            x: (document.canvasSize.width - avatarSize.width) * 0.5,
            y: (document.canvasSize.height - avatarSize.height) * 0.5
        )
        let origin = clampedComponentOrigin(proposedOrigin ?? defaultOrigin, componentSize: avatarSize)
        let avatarFrame = CGRect(origin: origin, size: avatarSize)
        let initials = L10n.text("xomo.component.avatar.defaultInitials")
        let initialsContent = ImageEditorTextContent(
            text: initials,
            color: .white,
            fontSize: XomoAvatarComponentStyle.labelFontSize,
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            isBold: true,
            alignment: .center
        )
        let initialsSize = initialsContent.layerSize()
        let initialsOrigin = CGPoint(
            x: avatarFrame.midX - initialsSize.width * 0.5,
            y: avatarFrame.midY - initialsSize.height * 0.5
        )

        pushUndo()
        var group = ImageEditorLayer.group(name: L10n.text("xomo.component.avatar.title"), size: document.canvasSize)
        group.blendMode = .passThrough

        var background = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.avatar.backgroundLayer"),
            frame: avatarFrame,
            content: ImageEditorShapeContent(
                kind: .ellipse,
                fillColor: XomoAvatarComponentStyle.fillColor,
                fillOpacity: 1,
                strokeColor: XomoAvatarComponentStyle.strokeColor,
                strokeWidth: XomoAvatarComponentStyle.strokeWidth,
                strokeOpacity: 1
            )
        )
        background.groupID = group.id

        var initialsLayer = ImageEditorLayer.text(
            name: L10n.format("imageEditor.layer.textName", initials),
            origin: initialsOrigin,
            content: initialsContent
        )
        initialsLayer.groupID = group.id

        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(contentsOf: [background, initialsLayer, group], at: insertionIndex)
        document.selectedLayerID = group.id
        document.selectedLayerIDs = [group.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("xomo.component.history.insert"))
        statusText = L10n.format("xomo.component.status.inserted", group.name)
    }

    private func insertXomoIcon(at proposedOrigin: CGPoint?) {
        let iconSize = CGSize(width: XomoIconComponentStyle.size, height: XomoIconComponentStyle.size)
        let defaultOrigin = CGPoint(
            x: (document.canvasSize.width - iconSize.width) * 0.5,
            y: (document.canvasSize.height - iconSize.height) * 0.5
        )
        let origin = clampedComponentOrigin(proposedOrigin ?? defaultOrigin, componentSize: iconSize)

        pushUndo()
        var group = ImageEditorLayer.group(name: L10n.text("xomo.component.icon.title"), size: document.canvasSize)
        group.blendMode = .passThrough

        var pathLayer = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.icon.starLayer"),
            frame: CGRect(origin: origin, size: iconSize),
            content: ImageEditorShapeContent(
                kind: .path,
                fillColor: XomoIconComponentStyle.fillColor,
                fillOpacity: 1,
                strokeColor: XomoIconComponentStyle.strokeColor,
                strokeWidth: XomoIconComponentStyle.strokeWidth,
                strokeOpacity: 1,
                pathPoints: XomoIconComponentStyle.starPoints,
                isPathClosed: true
            )
        )
        pathLayer.groupID = group.id

        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(contentsOf: [pathLayer, group], at: insertionIndex)
        document.selectedLayerID = group.id
        document.selectedLayerIDs = [group.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("xomo.component.history.insert"))
        statusText = L10n.format("xomo.component.status.inserted", group.name)
    }

    private func imagePlaceholderImage(size: CGSize) -> NSImage {
        let start = NSColor(deviceRed: 0.14, green: 0.37, blue: 0.78, alpha: 1)
        let end = NSColor(deviceRed: 0.49, green: 0.16, blue: 0.73, alpha: 1)
        return NSImage.rendered(size: size) { rect in
            NSGradient(starting: start, ending: end)?.draw(in: rect, angle: -35)
            NSColor.white.withAlphaComponent(0.16).setFill()
            NSBezierPath(ovalIn: CGRect(
                x: rect.width * 0.55,
                y: rect.height * 0.12,
                width: rect.width * 0.46,
                height: rect.width * 0.46
            )).fill()
            NSColor.white.withAlphaComponent(0.24).setFill()
            NSBezierPath(ovalIn: CGRect(
                x: rect.width * 0.08,
                y: rect.height * 0.50,
                width: rect.width * 0.25,
                height: rect.width * 0.25
            )).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func clampedComponentOrigin(_ origin: CGPoint, componentSize: CGSize) -> CGPoint {
        CGPoint(
            x: max(0, min(origin.x, max(0, document.canvasSize.width - componentSize.width))),
            y: max(0, min(origin.y, max(0, document.canvasSize.height - componentSize.height)))
        )
    }
}
