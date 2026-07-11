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

    func fillColor(tokens: XomoComponentThemeTokens) -> NSColor {
        switch self {
        case .primary, .icon:
            tokens.accent
        case .secondary:
            tokens.surface
        case .ghost:
            .clear
        }
    }

    var fillOpacity: CGFloat {
        self == .ghost ? 0 : 1
    }

    func strokeColor(tokens: XomoComponentThemeTokens) -> NSColor {
        switch self {
        case .primary, .icon:
            tokens.accentBorder
        case .secondary, .ghost:
            tokens.accent
        }
    }

    var strokeOpacity: CGFloat {
        self == .ghost ? 0 : 1
    }

    func labelColor(tokens: XomoComponentThemeTokens) -> NSColor {
        switch self {
        case .primary, .icon:
            tokens.onAccent
        case .secondary, .ghost:
            tokens.accent
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

private enum XomoInputVariant: Equatable {
    case standard
    case search
    case textArea
    case select

    var component: XomoComponentKind {
        switch self {
        case .standard: .input
        case .search: .searchInput
        case .textArea: .textArea
        case .select: .selectInput
        }
    }

    var height: CGFloat {
        switch self {
        case .textArea: 112
        case .standard, .search, .select: XomoInputComponentStyle.height
        }
    }

    var leadingAccessory: String? {
        self == .search ? "⌕" : nil
    }

    var trailingAccessory: String? {
        self == .select ? "⌄" : nil
    }
}

private enum XomoSelectionComponentStyle {
    static let toggleSize = CGSize(width: 52, height: 28)
    static let toggleKnobDiameter: CGFloat = 22
    static let checkboxSize: CGFloat = 20
    static let tagSize = CGSize(width: 96, height: 28)
    static let badgeDiameter: CGFloat = 28
    static let labelFontSize: CGFloat = 14
    static let fillColor = NSColor(deviceRed: 0.20, green: 0.48, blue: 0.95, alpha: 1)
    static let strokeColor = NSColor(deviceRed: 0.16, green: 0.39, blue: 0.78, alpha: 1)
    static let mutedFillColor = NSColor(deviceWhite: 0.94, alpha: 1)
    static let mutedTextColor = NSColor(deviceWhite: 0.26, alpha: 1)
    static let strokeWidth: CGFloat = 1
}

private enum XomoNavigationComponentStyle {
    static let minimumWidth: CGFloat = 260
    static let maximumWidth: CGFloat = 420
    static let widthRatio: CGFloat = 0.38
    static let topNavigationHeight: CGFloat = 56
    static let sideNavigationWidth: CGFloat = 200
    static let sideNavigationHeight: CGFloat = 220
    static let tabBarHeight: CGFloat = 44
    static let listRowHeight: CGFloat = 64
    static let titleFontSize: CGFloat = 15
    static let detailFontSize: CGFloat = 12
    static let inset: CGFloat = 16
    static let fillColor = NSColor(deviceWhite: 0.98, alpha: 1)
    static let selectedFillColor = NSColor(deviceRed: 0.20, green: 0.48, blue: 0.95, alpha: 1)
    static let strokeColor = NSColor(deviceWhite: 0.80, alpha: 1)
    static let titleColor = NSColor(deviceWhite: 0.16, alpha: 1)
    static let detailColor = NSColor(deviceWhite: 0.45, alpha: 1)
    static let strokeWidth: CGFloat = 1
}

private enum XomoContentComponentStyle {
    static let carouselHeight: CGFloat = 220
    static let carouselImageHeight: CGFloat = 150
    static let emptyStateSize = CGSize(width: 280, height: 180)
    static let emptyStateIconDiameter: CGFloat = 44
    static let titleFontSize: CGFloat = 17
    static let bodyFontSize: CGFloat = 13
    static let inset: CGFloat = 18
    static let iconFillColor = NSColor(deviceRed: 0.20, green: 0.48, blue: 0.95, alpha: 1)
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
    case searchInput
    case textArea
    case selectInput
    case toggle
    case checkbox
    case tag
    case badge
    case listRow
    case topNavigation
    case sideNavigation
    case tabBar
    case carouselCard
    case emptyState
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
            insertXomoInput(.standard, at: proposedOrigin)
        case .searchInput:
            insertXomoInput(.search, at: proposedOrigin)
        case .textArea:
            insertXomoInput(.textArea, at: proposedOrigin)
        case .selectInput:
            insertXomoInput(.select, at: proposedOrigin)
        case .toggle:
            insertXomoToggle(at: proposedOrigin)
        case .checkbox:
            insertXomoCheckbox(at: proposedOrigin)
        case .tag:
            insertXomoTag(at: proposedOrigin)
        case .badge:
            insertXomoBadge(at: proposedOrigin)
        case .listRow:
            insertXomoListRow(at: proposedOrigin)
        case .topNavigation:
            insertXomoTopNavigation(at: proposedOrigin)
        case .sideNavigation:
            insertXomoSideNavigation(at: proposedOrigin)
        case .tabBar:
            insertXomoTabBar(at: proposedOrigin)
        case .carouselCard:
            insertXomoCarouselCard(at: proposedOrigin)
        case .emptyState:
            insertXomoEmptyState(at: proposedOrigin)
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
        let tokens = xomoComponentTheme.tokens
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
            color: variant.labelColor(tokens: tokens),
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
                fillColor: variant.fillColor(tokens: tokens),
                fillOpacity: variant.fillOpacity,
                strokeColor: variant.strokeColor(tokens: tokens),
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

    private func insertXomoInput(_ variant: XomoInputVariant, at proposedOrigin: CGPoint?) {
        let canvasSize = document.canvasSize
        let inputSize = CGSize(
            width: min(
                XomoInputComponentStyle.maximumWidth,
                max(XomoInputComponentStyle.minimumWidth, canvasSize.width * XomoInputComponentStyle.widthRatio)
            ),
            height: variant.height
        )
        let defaultOrigin = CGPoint(
            x: (canvasSize.width - inputSize.width) * 0.5,
            y: (canvasSize.height - inputSize.height) * 0.5
        )
        let origin = clampedComponentOrigin(proposedOrigin ?? defaultOrigin, componentSize: inputSize)
        let inputFrame = CGRect(origin: origin, size: inputSize)
        let component = variant.component
        let placeholder = L10n.text("xomo.component.\(component.rawValue).defaultPlaceholder")
        let placeholderContent = ImageEditorTextContent(
            text: placeholder,
            color: XomoInputComponentStyle.textColor,
            fontSize: XomoInputComponentStyle.labelFontSize,
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            alignment: .left
        )
        let leadingInset = variant.leadingAccessory == nil
            ? ImageEditorTextContent.drawingPadding
            : ImageEditorTextContent.drawingPadding * 3
        let textOrigin = CGPoint(
            x: inputFrame.minX + leadingInset,
            y: variant == .textArea
                ? inputFrame.minY + ImageEditorTextContent.drawingPadding
                : inputFrame.midY - placeholderContent.layerSize().height * 0.5
        )

        pushUndo()
        var group = ImageEditorLayer.group(name: component.title, size: canvasSize)
        group.blendMode = .passThrough

        var background = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.\(component.rawValue).backgroundLayer"),
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

        var children = [background, text]
        if let leadingAccessory = variant.leadingAccessory {
            children.append(inputAccessoryLayer(
                leadingAccessory,
                name: L10n.text("xomo.component.searchInput.leadingAccessoryLayer"),
                origin: CGPoint(
                    x: inputFrame.minX + ImageEditorTextContent.drawingPadding,
                    y: inputFrame.midY - XomoInputComponentStyle.labelFontSize * 0.5
                ),
                groupID: group.id
            ))
        }
        if let trailingAccessory = variant.trailingAccessory {
            children.append(inputAccessoryLayer(
                trailingAccessory,
                name: L10n.text("xomo.component.selectInput.trailingAccessoryLayer"),
                origin: CGPoint(
                    x: inputFrame.maxX - XomoInputComponentStyle.labelFontSize * 2,
                    y: inputFrame.midY - XomoInputComponentStyle.labelFontSize * 0.5
                ),
                groupID: group.id
            ))
        }

        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(contentsOf: children + [group], at: insertionIndex)
        document.selectedLayerID = group.id
        document.selectedLayerIDs = [group.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("xomo.component.history.insert"))
        statusText = L10n.format("xomo.component.status.inserted", group.name)
    }

    private func inputAccessoryLayer(
        _ symbol: String,
        name: String,
        origin: CGPoint,
        groupID: UUID
    ) -> ImageEditorLayer {
        var layer = ImageEditorLayer.text(
            name: name,
            origin: origin,
            content: ImageEditorTextContent(
                text: symbol,
                color: XomoInputComponentStyle.textColor,
                fontSize: XomoInputComponentStyle.labelFontSize,
                point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
                alignment: .left
            )
        )
        layer.groupID = groupID
        return layer
    }

    private func insertXomoToggle(at proposedOrigin: CGPoint?) {
        let component = XomoComponentKind.toggle
        let frame = componentFrame(
            proposedOrigin,
            size: XomoSelectionComponentStyle.toggleSize
        )
        let knobFrame = CGRect(
            x: frame.maxX - XomoSelectionComponentStyle.toggleKnobDiameter - 3,
            y: frame.midY - XomoSelectionComponentStyle.toggleKnobDiameter * 0.5,
            width: XomoSelectionComponentStyle.toggleKnobDiameter,
            height: XomoSelectionComponentStyle.toggleKnobDiameter
        )
        let group = beginComponentGroup(component)
        var background = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.toggle.backgroundLayer"),
            frame: frame,
            content: ImageEditorShapeContent(
                kind: .ellipse,
                fillColor: XomoSelectionComponentStyle.fillColor,
                fillOpacity: 1,
                strokeColor: XomoSelectionComponentStyle.strokeColor,
                strokeWidth: XomoSelectionComponentStyle.strokeWidth,
                strokeOpacity: 1
            )
        )
        background.groupID = group.id
        var knob = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.toggle.knobLayer"),
            frame: knobFrame,
            content: ImageEditorShapeContent(
                kind: .ellipse,
                fillColor: .white,
                fillOpacity: 1,
                strokeColor: .white,
                strokeWidth: XomoSelectionComponentStyle.strokeWidth,
                strokeOpacity: 1
            )
        )
        knob.groupID = group.id
        finishComponentInsertion(group: group, children: [background, knob])
    }

    private func insertXomoCheckbox(at proposedOrigin: CGPoint?) {
        let component = XomoComponentKind.checkbox
        let label = L10n.text("xomo.component.checkbox.defaultLabel")
        let labelContent = ImageEditorTextContent(
            text: label,
            color: XomoSelectionComponentStyle.mutedTextColor,
            fontSize: XomoSelectionComponentStyle.labelFontSize,
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            alignment: .left
        )
        let labelSize = labelContent.layerSize()
        let componentSize = CGSize(
            width: XomoSelectionComponentStyle.checkboxSize + labelSize.width + 8,
            height: max(XomoSelectionComponentStyle.checkboxSize, labelSize.height)
        )
        let frame = componentFrame(proposedOrigin, size: componentSize)
        let boxFrame = CGRect(
            x: frame.minX,
            y: frame.midY - XomoSelectionComponentStyle.checkboxSize * 0.5,
            width: XomoSelectionComponentStyle.checkboxSize,
            height: XomoSelectionComponentStyle.checkboxSize
        )
        let group = beginComponentGroup(component)
        var box = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.checkbox.boxLayer"),
            frame: boxFrame,
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: XomoSelectionComponentStyle.fillColor,
                fillOpacity: 1,
                strokeColor: XomoSelectionComponentStyle.strokeColor,
                strokeWidth: XomoSelectionComponentStyle.strokeWidth,
                strokeOpacity: 1
            )
        )
        box.groupID = group.id
        var text = ImageEditorLayer.text(
            name: L10n.format("imageEditor.layer.textName", label),
            origin: CGPoint(x: boxFrame.maxX + 8, y: frame.midY - labelSize.height * 0.5),
            content: labelContent
        )
        text.groupID = group.id
        finishComponentInsertion(group: group, children: [box, text])
    }

    private func insertXomoTag(at proposedOrigin: CGPoint?) {
        let component = XomoComponentKind.tag
        let frame = componentFrame(proposedOrigin, size: XomoSelectionComponentStyle.tagSize)
        let label = L10n.text("xomo.component.tag.defaultLabel")
        let labelContent = ImageEditorTextContent(
            text: label,
            color: XomoSelectionComponentStyle.mutedTextColor,
            fontSize: XomoSelectionComponentStyle.labelFontSize,
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            alignment: .center
        )
        let labelSize = labelContent.layerSize()
        let group = beginComponentGroup(component)
        var background = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.tag.backgroundLayer"),
            frame: frame,
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: XomoSelectionComponentStyle.mutedFillColor,
                fillOpacity: 1,
                strokeColor: XomoSelectionComponentStyle.mutedFillColor,
                strokeWidth: XomoSelectionComponentStyle.strokeWidth,
                strokeOpacity: 1
            )
        )
        background.groupID = group.id
        var text = ImageEditorLayer.text(
            name: L10n.format("imageEditor.layer.textName", label),
            origin: CGPoint(x: frame.midX - labelSize.width * 0.5, y: frame.midY - labelSize.height * 0.5),
            content: labelContent
        )
        text.groupID = group.id
        finishComponentInsertion(group: group, children: [background, text])
    }

    private func insertXomoBadge(at proposedOrigin: CGPoint?) {
        let component = XomoComponentKind.badge
        let size = CGSize(
            width: XomoSelectionComponentStyle.badgeDiameter,
            height: XomoSelectionComponentStyle.badgeDiameter
        )
        let frame = componentFrame(proposedOrigin, size: size)
        let value = L10n.text("xomo.component.badge.defaultValue")
        let valueContent = ImageEditorTextContent(
            text: value,
            color: .white,
            fontSize: XomoSelectionComponentStyle.labelFontSize,
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            isBold: true,
            alignment: .center
        )
        let valueSize = valueContent.layerSize()
        let group = beginComponentGroup(component)
        var background = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.badge.backgroundLayer"),
            frame: frame,
            content: ImageEditorShapeContent(
                kind: .ellipse,
                fillColor: XomoSelectionComponentStyle.fillColor,
                fillOpacity: 1,
                strokeColor: XomoSelectionComponentStyle.strokeColor,
                strokeWidth: XomoSelectionComponentStyle.strokeWidth,
                strokeOpacity: 1
            )
        )
        background.groupID = group.id
        var text = ImageEditorLayer.text(
            name: L10n.format("imageEditor.layer.textName", value),
            origin: CGPoint(x: frame.midX - valueSize.width * 0.5, y: frame.midY - valueSize.height * 0.5),
            content: valueContent
        )
        text.groupID = group.id
        finishComponentInsertion(group: group, children: [background, text])
    }

    private func componentFrame(_ proposedOrigin: CGPoint?, size: CGSize) -> CGRect {
        let canvasSize = document.canvasSize
        let defaultOrigin = CGPoint(
            x: (canvasSize.width - size.width) * 0.5,
            y: (canvasSize.height - size.height) * 0.5
        )
        return CGRect(
            origin: clampedComponentOrigin(proposedOrigin ?? defaultOrigin, componentSize: size),
            size: size
        )
    }

    private func beginComponentGroup(_ component: XomoComponentKind) -> ImageEditorLayer {
        pushUndo()
        var group = ImageEditorLayer.group(name: component.title, size: document.canvasSize)
        group.blendMode = .passThrough
        return group
    }

    private func finishComponentInsertion(group: ImageEditorLayer, children: [ImageEditorLayer]) {
        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(contentsOf: children + [group], at: insertionIndex)
        document.selectedLayerID = group.id
        document.selectedLayerIDs = [group.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("xomo.component.history.insert"))
        statusText = L10n.format("xomo.component.status.inserted", group.name)
    }

    private func insertXomoListRow(at proposedOrigin: CGPoint?) {
        let component = XomoComponentKind.listRow
        let frame = componentFrame(
            proposedOrigin,
            size: CGSize(width: navigationWidth(), height: XomoNavigationComponentStyle.listRowHeight)
        )
        let title = L10n.text("xomo.component.listRow.defaultTitle")
        let detail = L10n.text("xomo.component.listRow.defaultDetail")
        let group = beginComponentGroup(component)
        var background = navigationBackground(
            name: L10n.text("xomo.component.listRow.backgroundLayer"),
            frame: frame,
            groupID: group.id
        )
        background.groupID = group.id
        let titleLayer = componentTextLayer(
            title,
            name: L10n.text("xomo.component.listRow.titleLayer"),
            color: XomoNavigationComponentStyle.titleColor,
            fontSize: XomoNavigationComponentStyle.titleFontSize,
            origin: CGPoint(x: frame.minX + XomoNavigationComponentStyle.inset, y: frame.minY + 10),
            isBold: true,
            groupID: group.id
        )
        let detailLayer = componentTextLayer(
            detail,
            name: L10n.text("xomo.component.listRow.detailLayer"),
            color: XomoNavigationComponentStyle.detailColor,
            fontSize: XomoNavigationComponentStyle.detailFontSize,
            origin: CGPoint(x: frame.minX + XomoNavigationComponentStyle.inset, y: frame.minY + 33),
            groupID: group.id
        )
        finishComponentInsertion(group: group, children: [background, titleLayer, detailLayer])
    }

    private func insertXomoTopNavigation(at proposedOrigin: CGPoint?) {
        let component = XomoComponentKind.topNavigation
        let frame = componentFrame(
            proposedOrigin,
            size: CGSize(width: navigationWidth(), height: XomoNavigationComponentStyle.topNavigationHeight)
        )
        let group = beginComponentGroup(component)
        let background = navigationBackground(
            name: L10n.text("xomo.component.topNavigation.backgroundLayer"),
            frame: frame,
            groupID: group.id
        )
        let brand = componentTextLayer(
            L10n.text("xomo.component.topNavigation.defaultBrand"),
            name: L10n.text("xomo.component.topNavigation.brandLayer"),
            color: XomoNavigationComponentStyle.titleColor,
            fontSize: XomoNavigationComponentStyle.titleFontSize,
            origin: CGPoint(x: frame.minX + XomoNavigationComponentStyle.inset, y: frame.midY - 11),
            isBold: true,
            groupID: group.id
        )
        let firstItem = componentTextLayer(
            L10n.text("xomo.component.topNavigation.defaultFirstItem"),
            name: L10n.text("xomo.component.topNavigation.firstItemLayer"),
            color: XomoNavigationComponentStyle.detailColor,
            fontSize: XomoNavigationComponentStyle.titleFontSize,
            origin: CGPoint(x: frame.maxX - 126, y: frame.midY - 11),
            groupID: group.id
        )
        let secondItem = componentTextLayer(
            L10n.text("xomo.component.topNavigation.defaultSecondItem"),
            name: L10n.text("xomo.component.topNavigation.secondItemLayer"),
            color: XomoNavigationComponentStyle.detailColor,
            fontSize: XomoNavigationComponentStyle.titleFontSize,
            origin: CGPoint(x: frame.maxX - 66, y: frame.midY - 11),
            groupID: group.id
        )
        finishComponentInsertion(group: group, children: [background, brand, firstItem, secondItem])
    }

    private func insertXomoSideNavigation(at proposedOrigin: CGPoint?) {
        let component = XomoComponentKind.sideNavigation
        let frame = componentFrame(
            proposedOrigin,
            size: CGSize(
                width: XomoNavigationComponentStyle.sideNavigationWidth,
                height: XomoNavigationComponentStyle.sideNavigationHeight
            )
        )
        let group = beginComponentGroup(component)
        let background = navigationBackground(
            name: L10n.text("xomo.component.sideNavigation.backgroundLayer"),
            frame: frame,
            groupID: group.id
        )
        let title = componentTextLayer(
            L10n.text("xomo.component.sideNavigation.defaultTitle"),
            name: L10n.text("xomo.component.sideNavigation.titleLayer"),
            color: XomoNavigationComponentStyle.titleColor,
            fontSize: XomoNavigationComponentStyle.titleFontSize,
            origin: CGPoint(x: frame.minX + XomoNavigationComponentStyle.inset, y: frame.minY + 16),
            isBold: true,
            groupID: group.id
        )
        var selectedItemBackground = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.sideNavigation.selectedItemBackgroundLayer"),
            frame: CGRect(
                x: frame.minX + 8,
                y: frame.minY + 56,
                width: frame.width - 16,
                height: 32
            ),
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: XomoNavigationComponentStyle.selectedFillColor,
                fillOpacity: 1,
                strokeColor: XomoNavigationComponentStyle.selectedFillColor,
                strokeWidth: XomoNavigationComponentStyle.strokeWidth,
                strokeOpacity: 1
            )
        )
        selectedItemBackground.groupID = group.id
        let firstItem = componentTextLayer(
            L10n.text("xomo.component.sideNavigation.defaultFirstItem"),
            name: L10n.text("xomo.component.sideNavigation.firstItemLayer"),
            color: .white,
            fontSize: XomoNavigationComponentStyle.titleFontSize,
            origin: CGPoint(x: frame.minX + XomoNavigationComponentStyle.inset, y: frame.minY + 70),
            groupID: group.id
        )
        let secondItem = componentTextLayer(
            L10n.text("xomo.component.sideNavigation.defaultSecondItem"),
            name: L10n.text("xomo.component.sideNavigation.secondItemLayer"),
            color: XomoNavigationComponentStyle.detailColor,
            fontSize: XomoNavigationComponentStyle.titleFontSize,
            origin: CGPoint(x: frame.minX + XomoNavigationComponentStyle.inset, y: frame.minY + 112),
            groupID: group.id
        )
        finishComponentInsertion(group: group, children: [background, title, selectedItemBackground, firstItem, secondItem])
    }

    private func insertXomoTabBar(at proposedOrigin: CGPoint?) {
        let component = XomoComponentKind.tabBar
        let frame = componentFrame(
            proposedOrigin,
            size: CGSize(width: navigationWidth(), height: XomoNavigationComponentStyle.tabBarHeight)
        )
        let group = beginComponentGroup(component)
        let background = navigationBackground(
            name: L10n.text("xomo.component.tabBar.backgroundLayer"),
            frame: frame,
            groupID: group.id
        )
        let names = [
            L10n.text("xomo.component.tabBar.defaultFirstItem"),
            L10n.text("xomo.component.tabBar.defaultSecondItem"),
            L10n.text("xomo.component.tabBar.defaultThirdItem")
        ]
        let itemWidth = frame.width / CGFloat(names.count)
        let itemLayers = names.enumerated().map { index, name in
            componentTextLayer(
                name,
                name: L10n.format("xomo.component.tabBar.itemLayer", index + 1),
                color: index == 0 ? XomoNavigationComponentStyle.selectedFillColor : XomoNavigationComponentStyle.detailColor,
                fontSize: XomoNavigationComponentStyle.titleFontSize,
                origin: CGPoint(
                    x: frame.minX + itemWidth * CGFloat(index) + XomoNavigationComponentStyle.inset,
                    y: frame.midY - 11
                ),
                isBold: index == 0,
                groupID: group.id
            )
        }
        finishComponentInsertion(group: group, children: [background] + itemLayers)
    }

    private func navigationWidth() -> CGFloat {
        min(
            XomoNavigationComponentStyle.maximumWidth,
            max(XomoNavigationComponentStyle.minimumWidth, document.canvasSize.width * XomoNavigationComponentStyle.widthRatio)
        )
    }

    private func navigationBackground(name: String, frame: CGRect, groupID: UUID) -> ImageEditorLayer {
        var background = ImageEditorLayer.shape(
            name: name,
            frame: frame,
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: XomoNavigationComponentStyle.fillColor,
                fillOpacity: 1,
                strokeColor: XomoNavigationComponentStyle.strokeColor,
                strokeWidth: XomoNavigationComponentStyle.strokeWidth,
                strokeOpacity: 1
            )
        )
        background.groupID = groupID
        return background
    }

    private func componentTextLayer(
        _ text: String,
        name: String,
        color: NSColor,
        fontSize: CGFloat,
        origin: CGPoint,
        isBold: Bool = false,
        groupID: UUID
    ) -> ImageEditorLayer {
        var layer = ImageEditorLayer.text(
            name: name,
            origin: origin,
            content: ImageEditorTextContent(
                text: text,
                color: color,
                fontSize: fontSize,
                point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
                isBold: isBold,
                alignment: .left
            )
        )
        layer.groupID = groupID
        return layer
    }

    private func insertXomoCarouselCard(at proposedOrigin: CGPoint?) {
        let component = XomoComponentKind.carouselCard
        let frame = componentFrame(
            proposedOrigin,
            size: CGSize(width: navigationWidth(), height: XomoContentComponentStyle.carouselHeight)
        )
        let imageFrame = CGRect(
            x: frame.minX,
            y: frame.minY,
            width: frame.width,
            height: XomoContentComponentStyle.carouselImageHeight
        )
        let group = beginComponentGroup(component)
        let background = navigationBackground(
            name: L10n.text("xomo.component.carouselCard.backgroundLayer"),
            frame: frame,
            groupID: group.id
        )
        var image = ImageEditorLayer(
            name: L10n.text("xomo.component.carouselCard.imageLayer"),
            image: imagePlaceholderImage(size: imageFrame.size),
            mask: nil,
            frame: imageFrame,
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false
        )
        image.groupID = group.id
        let title = componentTextLayer(
            L10n.text("xomo.component.carouselCard.defaultTitle"),
            name: L10n.text("xomo.component.carouselCard.titleLayer"),
            color: XomoNavigationComponentStyle.titleColor,
            fontSize: XomoContentComponentStyle.titleFontSize,
            origin: CGPoint(x: frame.minX + XomoContentComponentStyle.inset, y: imageFrame.maxY + 13),
            isBold: true,
            groupID: group.id
        )
        let dots = carouselDots(in: frame, groupID: group.id)
        finishComponentInsertion(group: group, children: [background, image, title] + dots)
    }

    private func insertXomoEmptyState(at proposedOrigin: CGPoint?) {
        let component = XomoComponentKind.emptyState
        let frame = componentFrame(proposedOrigin, size: XomoContentComponentStyle.emptyStateSize)
        let iconFrame = CGRect(
            x: frame.midX - XomoContentComponentStyle.emptyStateIconDiameter * 0.5,
            y: frame.minY + 24,
            width: XomoContentComponentStyle.emptyStateIconDiameter,
            height: XomoContentComponentStyle.emptyStateIconDiameter
        )
        let group = beginComponentGroup(component)
        let background = navigationBackground(
            name: L10n.text("xomo.component.emptyState.backgroundLayer"),
            frame: frame,
            groupID: group.id
        )
        var icon = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.emptyState.iconLayer"),
            frame: iconFrame,
            content: ImageEditorShapeContent(
                kind: .ellipse,
                fillColor: XomoContentComponentStyle.iconFillColor,
                fillOpacity: 1,
                strokeColor: XomoContentComponentStyle.iconFillColor,
                strokeWidth: XomoNavigationComponentStyle.strokeWidth,
                strokeOpacity: 1
            )
        )
        icon.groupID = group.id
        let title = L10n.text("xomo.component.emptyState.defaultTitle")
        let body = L10n.text("xomo.component.emptyState.defaultBody")
        let titleSize = componentTextSize(title, fontSize: XomoContentComponentStyle.titleFontSize, isBold: true)
        let bodySize = componentTextSize(body, fontSize: XomoContentComponentStyle.bodyFontSize)
        let titleLayer = componentTextLayer(
            title,
            name: L10n.text("xomo.component.emptyState.titleLayer"),
            color: XomoNavigationComponentStyle.titleColor,
            fontSize: XomoContentComponentStyle.titleFontSize,
            origin: CGPoint(x: frame.midX - titleSize.width * 0.5, y: frame.minY + 84),
            isBold: true,
            groupID: group.id
        )
        let bodyLayer = componentTextLayer(
            body,
            name: L10n.text("xomo.component.emptyState.bodyLayer"),
            color: XomoNavigationComponentStyle.detailColor,
            fontSize: XomoContentComponentStyle.bodyFontSize,
            origin: CGPoint(x: frame.midX - bodySize.width * 0.5, y: frame.minY + 116),
            groupID: group.id
        )
        finishComponentInsertion(group: group, children: [background, icon, titleLayer, bodyLayer])
    }

    private func carouselDots(in frame: CGRect, groupID: UUID) -> [ImageEditorLayer] {
        let dotDiameter: CGFloat = 6
        let dotGap: CGFloat = 7
        let totalWidth = dotDiameter * 3 + dotGap * 2
        return (0..<3).map { index in
            var dot = ImageEditorLayer.shape(
                name: L10n.format("xomo.component.carouselCard.dotLayer", index + 1),
                frame: CGRect(
                    x: frame.midX - totalWidth * 0.5 + CGFloat(index) * (dotDiameter + dotGap),
                    y: frame.maxY - 14,
                    width: dotDiameter,
                    height: dotDiameter
                ),
                content: ImageEditorShapeContent(
                    kind: .ellipse,
                    fillColor: index == 0 ? XomoNavigationComponentStyle.selectedFillColor : XomoNavigationComponentStyle.strokeColor,
                    fillOpacity: 1,
                    strokeColor: .clear,
                    strokeWidth: XomoNavigationComponentStyle.strokeWidth,
                    strokeOpacity: 0
                )
            )
            dot.groupID = groupID
            return dot
        }
    }

    private func componentTextSize(_ text: String, fontSize: CGFloat, isBold: Bool = false) -> CGSize {
        ImageEditorTextContent(
            text: text,
            color: .black,
            fontSize: fontSize,
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            isBold: isBold,
            alignment: .left
        ).layerSize()
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
