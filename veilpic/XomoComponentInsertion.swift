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

private struct XomoThemeSampleItem {
    let component: XomoComponentKind
    let relativeOrigin: CGPoint
}

private enum XomoButtonVariant: Equatable {
    case primary
    case secondary
    case ghost
    case icon

    init(component: XomoComponentKind) {
        switch component {
        case .button:
            self = .primary
        case .secondaryButton:
            self = .secondary
        case .ghostButton:
            self = .ghost
        case .iconButton:
            self = .icon
        default:
            self = .primary
        }
    }

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
    static let strokeWidth: CGFloat = 1
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

enum XomoComponentKind: String, CaseIterable, Identifiable, Codable {
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

    var supportsThemeApplication: Bool {
        true
    }
}

extension ImageEditorViewModel {
    func insertXomoThemeSample() {
        let sample = XomoThemeSample.sample(for: xomoComponentTheme)
        xomoThemeSampleItems(for: sample).forEach { item in
            insertXomoComponent(item.component, at: xomoThemeSampleOrigin(for: item.relativeOrigin))
        }
        statusText = L10n.format("xomo.themeSample.status.inserted", sample.title)
    }

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

    func xomoComponentSize(_ component: XomoComponentKind) -> CGSize {
        let canvasWidth = document.canvasSize.width
        let buttonWidth = min(
            XomoButtonComponentStyle.maximumWidth,
            max(XomoButtonComponentStyle.minimumWidth, canvasWidth * XomoButtonComponentStyle.widthRatio)
        )
        let inputWidth = min(
            XomoInputComponentStyle.maximumWidth,
            max(XomoInputComponentStyle.minimumWidth, canvasWidth * XomoInputComponentStyle.widthRatio)
        )
        let cardWidth = min(
            XomoCardComponentStyle.maximumWidth,
            max(XomoCardComponentStyle.minimumWidth, canvasWidth * XomoCardComponentStyle.widthRatio)
        )
        let imageWidth = min(
            XomoImageComponentStyle.maximumWidth,
            max(XomoImageComponentStyle.minimumWidth, canvasWidth * XomoImageComponentStyle.widthRatio)
        )

        switch component {
        case .button, .secondaryButton, .ghostButton:
            return CGSize(width: buttonWidth, height: XomoButtonComponentStyle.height)
        case .iconButton:
            return CGSize(width: XomoButtonComponentStyle.height, height: XomoButtonComponentStyle.height)
        case .input, .searchInput, .selectInput:
            return CGSize(width: inputWidth, height: XomoInputComponentStyle.height)
        case .textArea:
            return CGSize(width: inputWidth, height: XomoInputVariant.textArea.height)
        case .toggle:
            return XomoSelectionComponentStyle.toggleSize
        case .checkbox:
            let labelSize = componentTextSize(
                L10n.text("xomo.component.checkbox.defaultLabel"),
                fontSize: XomoSelectionComponentStyle.labelFontSize
            )
            return CGSize(
                width: XomoSelectionComponentStyle.checkboxSize + labelSize.width + 8,
                height: max(XomoSelectionComponentStyle.checkboxSize, labelSize.height)
            )
        case .tag:
            return XomoSelectionComponentStyle.tagSize
        case .badge:
            return CGSize(
                width: XomoSelectionComponentStyle.badgeDiameter,
                height: XomoSelectionComponentStyle.badgeDiameter
            )
        case .listRow:
            return CGSize(width: navigationWidth(), height: XomoNavigationComponentStyle.listRowHeight)
        case .topNavigation:
            return CGSize(width: navigationWidth(), height: XomoNavigationComponentStyle.topNavigationHeight)
        case .sideNavigation:
            return CGSize(
                width: XomoNavigationComponentStyle.sideNavigationWidth,
                height: XomoNavigationComponentStyle.sideNavigationHeight
            )
        case .tabBar:
            return CGSize(width: navigationWidth(), height: XomoNavigationComponentStyle.tabBarHeight)
        case .carouselCard:
            return CGSize(width: navigationWidth(), height: XomoContentComponentStyle.carouselHeight)
        case .emptyState:
            return XomoContentComponentStyle.emptyStateSize
        case .card:
            return CGSize(width: cardWidth, height: XomoCardComponentStyle.height)
        case .image:
            return CGSize(width: imageWidth, height: imageWidth / XomoImageComponentStyle.aspectRatio)
        case .avatar:
            return CGSize(width: XomoAvatarComponentStyle.diameter, height: XomoAvatarComponentStyle.diameter)
        case .icon:
            return CGSize(width: XomoIconComponentStyle.size, height: XomoIconComponentStyle.size)
        }
    }

    func xomoComponentDragPreviewSize(_ component: XomoComponentKind) -> CGSize {
        let componentSize = xomoComponentSize(component)
        let viewportSize = canvasViewportSize
        guard viewportSize.width > 0, viewportSize.height > 0 else {
            return componentSize
        }

        let imageRect = ImageEditorCanvasGeometry.fittedImageRect(
            canvasSize: document.canvasSize,
            viewportSize: viewportSize,
            zoom: zoom,
            canvasOffset: canvasOffset
        )
        let displayScale = imageRect.width / max(document.canvasSize.width, 1)
        return CGSize(
            width: max(1, componentSize.width * displayScale),
            height: max(1, componentSize.height * displayScale)
        )
    }

    func xomoComponentDropOrigin(
        _ component: XomoComponentKind,
        centeredAt canvasPoint: CGPoint
    ) -> CGPoint {
        let componentSize = xomoComponentSize(component)
        return clampedComponentOrigin(
            CGPoint(
                x: canvasPoint.x - componentSize.width * 0.5,
                y: canvasPoint.y - componentSize.height * 0.5
            ),
            componentSize: componentSize
        )
    }

    private func insertXomoButton(_ variant: XomoButtonVariant, at proposedOrigin: CGPoint?) {
        let canvasSize = document.canvasSize
        let tokens = xomoComponentTheme.tokens
        let buttonSize = xomoComponentSize(variant.component)
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
        group.xomoComponentInstance = XomoComponentInstance(kind: component, theme: xomoComponentTheme)

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
        let tokens = xomoComponentTheme.tokens
        let inputSize = xomoComponentSize(variant.component)
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
            color: tokens.secondaryText,
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
        group.xomoComponentInstance = XomoComponentInstance(kind: component, theme: xomoComponentTheme)

        var background = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.\(component.rawValue).backgroundLayer"),
            frame: inputFrame,
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: tokens.surface,
                fillOpacity: 1,
                strokeColor: tokens.border,
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
                color: tokens.secondaryText,
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
                color: tokens.secondaryText,
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
        color: NSColor,
        groupID: UUID
    ) -> ImageEditorLayer {
        var layer = ImageEditorLayer.text(
            name: name,
            origin: origin,
            content: ImageEditorTextContent(
                text: symbol,
                color: color,
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
        let tokens = xomoComponentTheme.tokens
        let frame = componentFrame(
            proposedOrigin,
            size: xomoComponentSize(component)
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
                fillColor: tokens.accent,
                fillOpacity: 1,
                strokeColor: tokens.accentBorder,
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
                fillColor: tokens.onAccent,
                fillOpacity: 1,
                strokeColor: tokens.onAccent,
                strokeWidth: XomoSelectionComponentStyle.strokeWidth,
                strokeOpacity: 1
            )
        )
        knob.groupID = group.id
        finishComponentInsertion(group: group, children: [background, knob])
    }

    private func insertXomoCheckbox(at proposedOrigin: CGPoint?) {
        let component = XomoComponentKind.checkbox
        let tokens = xomoComponentTheme.tokens
        let label = L10n.text("xomo.component.checkbox.defaultLabel")
        let labelContent = ImageEditorTextContent(
            text: label,
            color: tokens.secondaryText,
            fontSize: XomoSelectionComponentStyle.labelFontSize,
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            alignment: .left
        )
        let labelSize = labelContent.layerSize()
        let componentSize = xomoComponentSize(component)
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
                fillColor: tokens.surface,
                fillOpacity: 1,
                strokeColor: tokens.border,
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
        let tokens = xomoComponentTheme.tokens
        let frame = componentFrame(proposedOrigin, size: xomoComponentSize(component))
        let label = L10n.text("xomo.component.tag.defaultLabel")
        let labelContent = ImageEditorTextContent(
            text: label,
            color: tokens.secondaryText,
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
                fillColor: tokens.subtleSurface,
                fillOpacity: 1,
                strokeColor: tokens.border,
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
        let tokens = xomoComponentTheme.tokens
        let size = xomoComponentSize(component)
        let frame = componentFrame(proposedOrigin, size: size)
        let value = L10n.text("xomo.component.badge.defaultValue")
        let valueContent = ImageEditorTextContent(
            text: value,
            color: tokens.onAccent,
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
                fillColor: tokens.accent,
                fillOpacity: 1,
                strokeColor: tokens.accentBorder,
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
        group.xomoComponentInstance = XomoComponentInstance(kind: component, theme: xomoComponentTheme)
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
            size: xomoComponentSize(component)
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
            size: xomoComponentSize(component)
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
        let tokens = xomoComponentTheme.tokens
        let frame = componentFrame(
            proposedOrigin,
            size: xomoComponentSize(component)
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
                fillColor: tokens.accent,
                fillOpacity: 1,
                strokeColor: tokens.accentBorder,
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
            size: xomoComponentSize(component)
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
        let tokens = xomoComponentTheme.tokens
        var background = ImageEditorLayer.shape(
            name: name,
            frame: frame,
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: tokens.surface,
                fillOpacity: 1,
                strokeColor: tokens.border,
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
        let tokens = xomoComponentTheme.tokens
        var layer = ImageEditorLayer.text(
            name: name,
            origin: origin,
            content: ImageEditorTextContent(
                text: text,
                color: resolvedXomoComponentTextColor(color, tokens: tokens),
                fontSize: fontSize,
                point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
                isBold: isBold,
                alignment: .left
            )
        )
        layer.groupID = groupID
        return layer
    }

    private func resolvedXomoComponentTextColor(_ color: NSColor, tokens: XomoComponentThemeTokens) -> NSColor {
        if color.isEqual(NSColor.white) { return tokens.onAccent }
        if color.isEqual(XomoNavigationComponentStyle.titleColor) { return tokens.primaryText }
        if color.isEqual(XomoNavigationComponentStyle.selectedFillColor) { return tokens.accent }
        return tokens.secondaryText
    }

    private func insertXomoCarouselCard(at proposedOrigin: CGPoint?) {
        let component = XomoComponentKind.carouselCard
        let frame = componentFrame(
            proposedOrigin,
            size: xomoComponentSize(component)
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
        let tokens = xomoComponentTheme.tokens
        let frame = componentFrame(proposedOrigin, size: xomoComponentSize(component))
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
                fillColor: tokens.accent,
                fillOpacity: 1,
                strokeColor: tokens.accentBorder,
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
        let tokens = xomoComponentTheme.tokens
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
                    fillColor: index == 0 ? tokens.accent : tokens.border,
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
        let tokens = xomoComponentTheme.tokens
        let cardSize = xomoComponentSize(.card)
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
            color: tokens.primaryText,
            fontSize: XomoCardComponentStyle.titleFontSize,
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            isBold: true,
            alignment: .left
        )
        let bodyContent = ImageEditorTextContent(
            text: body,
            color: tokens.secondaryText,
            fontSize: XomoCardComponentStyle.bodyFontSize,
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            alignment: .left
        )

        pushUndo()
        var group = ImageEditorLayer.group(name: L10n.text("xomo.component.card.title"), size: canvasSize)
        group.blendMode = .passThrough
        group.xomoComponentInstance = XomoComponentInstance(kind: .card, theme: xomoComponentTheme)

        var background = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.card.backgroundLayer"),
            frame: cardFrame,
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: tokens.surface,
                fillOpacity: 1,
                strokeColor: tokens.border,
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
        let imageSize = xomoComponentSize(.image)
        let defaultOrigin = CGPoint(
            x: (canvasSize.width - imageSize.width) * 0.5,
            y: (canvasSize.height - imageSize.height) * 0.5
        )
        let origin = clampedComponentOrigin(proposedOrigin ?? defaultOrigin, componentSize: imageSize)

        pushUndo()
        var group = ImageEditorLayer.group(name: L10n.text("xomo.component.image.title"), size: canvasSize)
        group.blendMode = .passThrough
        group.xomoComponentInstance = XomoComponentInstance(kind: .image, theme: xomoComponentTheme)

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
        let tokens = xomoComponentTheme.tokens
        let avatarSize = xomoComponentSize(.avatar)
        let defaultOrigin = CGPoint(
            x: (document.canvasSize.width - avatarSize.width) * 0.5,
            y: (document.canvasSize.height - avatarSize.height) * 0.5
        )
        let origin = clampedComponentOrigin(proposedOrigin ?? defaultOrigin, componentSize: avatarSize)
        let avatarFrame = CGRect(origin: origin, size: avatarSize)
        let initials = L10n.text("xomo.component.avatar.defaultInitials")
        let initialsContent = ImageEditorTextContent(
            text: initials,
            color: tokens.onAccent,
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
        group.xomoComponentInstance = XomoComponentInstance(kind: .avatar, theme: xomoComponentTheme)

        var background = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.avatar.backgroundLayer"),
            frame: avatarFrame,
            content: ImageEditorShapeContent(
                kind: .ellipse,
                fillColor: tokens.accent,
                fillOpacity: 1,
                strokeColor: tokens.accentBorder,
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
        let tokens = xomoComponentTheme.tokens
        let iconSize = xomoComponentSize(.icon)
        let defaultOrigin = CGPoint(
            x: (document.canvasSize.width - iconSize.width) * 0.5,
            y: (document.canvasSize.height - iconSize.height) * 0.5
        )
        let origin = clampedComponentOrigin(proposedOrigin ?? defaultOrigin, componentSize: iconSize)

        pushUndo()
        var group = ImageEditorLayer.group(name: L10n.text("xomo.component.icon.title"), size: document.canvasSize)
        group.blendMode = .passThrough
        group.xomoComponentInstance = XomoComponentInstance(kind: .icon, theme: xomoComponentTheme)

        var pathLayer = ImageEditorLayer.shape(
            name: L10n.text("xomo.component.icon.starLayer"),
            frame: CGRect(origin: origin, size: iconSize),
            content: ImageEditorShapeContent(
                kind: .path,
                fillColor: tokens.accent,
                fillOpacity: 1,
                strokeColor: tokens.accentBorder,
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

    var canApplyXomoThemeToSelectedComponent: Bool {
        guard let groupIndex = selectedXomoComponentGroupIndex(),
              let component = xomoComponentKind(for: document.layers[groupIndex])
        else {
            return false
        }
        return component.supportsThemeApplication
    }

    var canToggleSelectedXomoThemeOverride: Bool {
        document.selectedLayerIDs.contains { layerID in
            guard let layerIndex = document.layers.firstIndex(where: { $0.id == layerID }),
                  !document.layers[layerIndex].isGroup,
                  let groupID = document.layers[layerIndex].groupID,
                  let group = document.layers.first(where: { $0.id == groupID })
            else {
                return false
            }
            return xomoComponentKind(for: group)?.supportsThemeApplication == true
        }
    }

    func applyXomoThemeToSelectedComponent() {
        guard let groupIndex = selectedXomoComponentGroupIndex(),
              let component = xomoComponentKind(for: document.layers[groupIndex]),
              component.supportsThemeApplication
        else {
            statusText = L10n.text("xomo.theme.status.noApplicableComponent")
            return
        }

        let groupID = document.layers[groupIndex].id
        let tokens = xomoComponentTheme.tokens
        pushUndo()
        for layerIndex in document.layers.indices where document.layers[layerIndex].groupID == groupID {
            guard !document.layers[layerIndex].isXomoThemeOverride else { continue }
            applyXomoTheme(tokens, to: &document.layers[layerIndex], component: component)
        }
        document.layers[groupIndex].xomoComponentInstance = XomoComponentInstance(
            kind: component,
            theme: xomoComponentTheme,
            masterID: document.layers[groupIndex].xomoComponentInstance?.masterID
        )
        appendHistory(L10n.text("xomo.theme.history.apply"))
        statusText = L10n.format("xomo.theme.status.applied", component.title, xomoComponentTheme.title)
    }

    func toggleXomoThemeOverrideForSelectedLayers() {
        let selectedIndices = document.layers.indices.filter { document.selectedLayerIDs.contains(document.layers[$0].id) }
        let eligibleIndices = selectedIndices.filter { index in
            let layer = document.layers[index]
            guard !layer.isGroup,
                  let groupID = layer.groupID,
                  let group = document.layers.first(where: { $0.id == groupID })
            else {
                return false
            }
            return xomoComponentKind(for: group)?.supportsThemeApplication == true
        }
        guard !eligibleIndices.isEmpty else {
            statusText = L10n.text("xomo.theme.status.noOverrideLayer")
            return
        }

        let shouldEnable = eligibleIndices.contains { !document.layers[$0].isXomoThemeOverride }
        pushUndo()
        for index in eligibleIndices {
            document.layers[index].isXomoThemeOverride = shouldEnable
        }
        appendHistory(L10n.text(shouldEnable ? "xomo.theme.history.overrideKeep" : "xomo.theme.history.overrideClear"))
        statusText = L10n.format(
            shouldEnable ? "xomo.theme.status.overrideKept" : "xomo.theme.status.overrideCleared",
            eligibleIndices.count
        )
    }

    var canSetSelectedXomoComponentAsMaster: Bool {
        guard let groupIndex = selectedXomoComponentGroupIndex(),
              let component = xomoComponentKind(for: document.layers[groupIndex])
        else {
            return false
        }
        return component.supportsThemeApplication
    }

    var canLinkSelectedXomoComponentsToMaster: Bool {
        guard let component = selectedXomoComponentGroupKind(),
              let masterIndex = xomoMasterComponentGroupIndex(for: component)
        else {
            return false
        }
        return selectedXomoComponentGroupIndices().contains { $0 != masterIndex }
    }

    var canSyncSelectedXomoComponentMaster: Bool {
        guard let groupIndex = selectedXomoComponentGroupIndex(),
              let masterIndex = xomoMasterComponentGroupIndex(for: groupIndex)
        else {
            return false
        }
        let masterID = document.layers[masterIndex].id
        return document.layers.contains { $0.xomoComponentInstance?.masterID == masterID && $0.id != masterID }
    }

    var canDetachSelectedXomoComponentInstances: Bool {
        selectedXomoComponentGroupIndices().contains { index in
            guard let masterID = document.layers[index].xomoComponentInstance?.masterID else { return false }
            return masterID != document.layers[index].id
        }
    }

    func setSelectedXomoComponentAsMaster() {
        guard let groupIndex = selectedXomoComponentGroupIndex(),
              let component = xomoComponentKind(for: document.layers[groupIndex]),
              component.supportsThemeApplication
        else {
            statusText = L10n.text("xomo.instance.status.noApplicableComponent")
            return
        }

        let groupID = document.layers[groupIndex].id
        pushUndo()
        document.layers[groupIndex].xomoComponentInstance = XomoComponentInstance(
            kind: component,
            theme: document.layers[groupIndex].xomoComponentInstance?.theme ?? xomoComponentTheme,
            masterID: groupID
        )
        xomoActiveMasterID = groupID
        appendHistory(L10n.text("xomo.instance.history.makeMaster"))
        statusText = L10n.format("xomo.instance.status.masterSet", component.title)
    }

    func linkSelectedXomoComponentsToMaster() {
        guard let component = selectedXomoComponentGroupKind(),
              let masterIndex = xomoMasterComponentGroupIndex(for: component)
        else {
            statusText = L10n.text("xomo.instance.status.noMaster")
            return
        }

        let masterID = document.layers[masterIndex].id
        let masterTheme = document.layers[masterIndex].xomoComponentInstance?.theme ?? xomoComponentTheme
        let targetIndices = selectedXomoComponentGroupIndices().filter { $0 != masterIndex }
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("xomo.instance.status.noLinkTarget")
            return
        }

        pushUndo()
        for targetIndex in targetIndices {
            applyXomoThemeToComponentGroup(targetIndex, component: component, theme: masterTheme)
            document.layers[targetIndex].xomoComponentInstance?.masterID = masterID
        }
        xomoActiveMasterID = masterID
        appendHistory(L10n.text("xomo.instance.history.link"))
        statusText = L10n.format("xomo.instance.status.linked", targetIndices.count, component.title)
    }

    func syncSelectedXomoComponentMaster() {
        guard let groupIndex = selectedXomoComponentGroupIndex(),
              let masterIndex = xomoMasterComponentGroupIndex(for: groupIndex),
              let component = xomoComponentKind(for: document.layers[masterIndex])
        else {
            statusText = L10n.text("xomo.instance.status.noMaster")
            return
        }

        let masterID = document.layers[masterIndex].id
        let masterTheme = document.layers[masterIndex].xomoComponentInstance?.theme ?? xomoComponentTheme
        let instanceIndices = document.layers.indices.filter {
            document.layers[$0].id != masterID && document.layers[$0].xomoComponentInstance?.masterID == masterID
        }
        guard !instanceIndices.isEmpty else {
            statusText = L10n.text("xomo.instance.status.noLinkedInstances")
            return
        }

        pushUndo()
        for instanceIndex in instanceIndices {
            applyXomoThemeToComponentGroup(instanceIndex, component: component, theme: masterTheme)
            document.layers[instanceIndex].xomoComponentInstance?.masterID = masterID
        }
        xomoActiveMasterID = masterID
        appendHistory(L10n.text("xomo.instance.history.sync"))
        statusText = L10n.format("xomo.instance.status.synced", instanceIndices.count, component.title)
    }

    func detachSelectedXomoComponentInstances() {
        let targetIndices = selectedXomoComponentGroupIndices().filter {
            guard let masterID = document.layers[$0].xomoComponentInstance?.masterID else { return false }
            return masterID != document.layers[$0].id
        }
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("xomo.instance.status.noDetachTarget")
            return
        }

        pushUndo()
        for targetIndex in targetIndices {
            document.layers[targetIndex].xomoComponentInstance?.masterID = nil
        }
        appendHistory(L10n.text("xomo.instance.history.detach"))
        statusText = L10n.format("xomo.instance.status.detached", targetIndices.count)
    }

    private func selectedXomoComponentGroupIndex() -> Int? {
        guard let selectedLayerID = document.selectedLayerID,
              let selectedIndex = document.layers.firstIndex(where: { $0.id == selectedLayerID })
        else {
            return nil
        }
        let selectedLayer = document.layers[selectedIndex]
        if selectedLayer.isGroup {
            return xomoComponentKind(for: selectedLayer) == nil ? nil : selectedIndex
        }
        guard let groupID = selectedLayer.groupID else { return nil }
        return document.layers.firstIndex { layer in
            layer.id == groupID && xomoComponentKind(for: layer) != nil
        }
    }

    private func selectedXomoComponentGroupIndices() -> [Int] {
        let groupIDs = Set(document.selectedLayerIDs.compactMap { selectedLayerID -> UUID? in
            guard let selectedLayer = document.layers.first(where: { $0.id == selectedLayerID }) else { return nil }
            return selectedLayer.isGroup ? selectedLayer.id : selectedLayer.groupID
        })
        return document.layers.indices.filter { groupIDs.contains(document.layers[$0].id) && xomoComponentKind(for: document.layers[$0]) != nil }
    }

    private func selectedXomoComponentGroupKind() -> XomoComponentKind? {
        let groupIndices = selectedXomoComponentGroupIndices()
        guard let firstIndex = groupIndices.first,
              groupIndices.allSatisfy({ xomoComponentKind(for: document.layers[$0]) == xomoComponentKind(for: document.layers[firstIndex]) })
        else {
            return nil
        }
        return xomoComponentKind(for: document.layers[firstIndex])
    }

    private func xomoMasterComponentGroupIndex(for component: XomoComponentKind) -> Int? {
        if let activeMasterID = xomoActiveMasterID,
           let activeIndex = document.layers.firstIndex(where: { $0.id == activeMasterID }),
           document.layers[activeIndex].xomoComponentInstance?.masterID == activeMasterID,
           xomoComponentKind(for: document.layers[activeIndex]) == component {
            return activeIndex
        }
        return document.layers.firstIndex { layer in
            layer.xomoComponentInstance?.masterID == layer.id && xomoComponentKind(for: layer) == component
        }
    }

    private func xomoMasterComponentGroupIndex(for groupIndex: Int) -> Int? {
        guard let masterID = document.layers[groupIndex].xomoComponentInstance?.masterID else { return nil }
        if masterID == document.layers[groupIndex].id { return groupIndex }
        return document.layers.firstIndex { $0.id == masterID && $0.xomoComponentInstance?.masterID == masterID }
    }

    private func applyXomoThemeToComponentGroup(
        _ groupIndex: Int,
        component: XomoComponentKind,
        theme: XomoComponentTheme
    ) {
        let groupID = document.layers[groupIndex].id
        for layerIndex in document.layers.indices where document.layers[layerIndex].groupID == groupID {
            guard !document.layers[layerIndex].isXomoThemeOverride else { continue }
            applyXomoTheme(theme.tokens, to: &document.layers[layerIndex], component: component)
        }
        document.layers[groupIndex].xomoComponentInstance = XomoComponentInstance(
            kind: component,
            theme: theme,
            masterID: document.layers[groupIndex].xomoComponentInstance?.masterID
        )
    }

    private func xomoComponentKind(for group: ImageEditorLayer) -> XomoComponentKind? {
        if let kind = group.xomoComponentInstance?.kind {
            return kind
        }
        return XomoComponentKind.allCases.first { $0.title == group.name }
    }

    private func xomoThemeSampleItems(for sample: XomoThemeSample) -> [XomoThemeSampleItem] {
        switch sample {
        case .nativeWorkspace:
            [
                XomoThemeSampleItem(component: .topNavigation, relativeOrigin: CGPoint(x: 0, y: 0)),
                XomoThemeSampleItem(component: .sideNavigation, relativeOrigin: CGPoint(x: 0, y: 0.08)),
                XomoThemeSampleItem(component: .card, relativeOrigin: CGPoint(x: 0.34, y: 0.18)),
                XomoThemeSampleItem(component: .input, relativeOrigin: CGPoint(x: 0.38, y: 0.43)),
                XomoThemeSampleItem(component: .selectInput, relativeOrigin: CGPoint(x: 0.38, y: 0.55)),
                XomoThemeSampleItem(component: .button, relativeOrigin: CGPoint(x: 0.38, y: 0.67))
            ]
        case .softMobileProfile:
            [
                XomoThemeSampleItem(component: .avatar, relativeOrigin: CGPoint(x: 0.42, y: 0.08)),
                XomoThemeSampleItem(component: .card, relativeOrigin: CGPoint(x: 0.14, y: 0.22)),
                XomoThemeSampleItem(component: .input, relativeOrigin: CGPoint(x: 0.15, y: 0.43)),
                XomoThemeSampleItem(component: .searchInput, relativeOrigin: CGPoint(x: 0.15, y: 0.54)),
                XomoThemeSampleItem(component: .button, relativeOrigin: CGPoint(x: 0.15, y: 0.66)),
                XomoThemeSampleItem(component: .secondaryButton, relativeOrigin: CGPoint(x: 0.15, y: 0.76))
            ]
        case .socialContentFeed:
            [
                XomoThemeSampleItem(component: .topNavigation, relativeOrigin: CGPoint(x: 0, y: 0)),
                XomoThemeSampleItem(component: .avatar, relativeOrigin: CGPoint(x: 0.10, y: 0.18)),
                XomoThemeSampleItem(component: .carouselCard, relativeOrigin: CGPoint(x: 0.18, y: 0.16)),
                XomoThemeSampleItem(component: .tabBar, relativeOrigin: CGPoint(x: 0.18, y: 0.54)),
                XomoThemeSampleItem(component: .tag, relativeOrigin: CGPoint(x: 0.22, y: 0.66)),
                XomoThemeSampleItem(component: .button, relativeOrigin: CGPoint(x: 0.48, y: 0.64))
            ]
        case .glassmorphismDashboard:
            [
                XomoThemeSampleItem(component: .topNavigation, relativeOrigin: CGPoint(x: 0, y: 0)),
                XomoThemeSampleItem(component: .card, relativeOrigin: CGPoint(x: 0.17, y: 0.18)),
                XomoThemeSampleItem(component: .card, relativeOrigin: CGPoint(x: 0.52, y: 0.18)),
                XomoThemeSampleItem(component: .searchInput, relativeOrigin: CGPoint(x: 0.22, y: 0.48)),
                XomoThemeSampleItem(component: .toggle, relativeOrigin: CGPoint(x: 0.62, y: 0.51)),
                XomoThemeSampleItem(component: .button, relativeOrigin: CGPoint(x: 0.40, y: 0.66))
            ]
        case .denseAdminSettings:
            [
                XomoThemeSampleItem(component: .topNavigation, relativeOrigin: CGPoint(x: 0, y: 0)),
                XomoThemeSampleItem(component: .sideNavigation, relativeOrigin: CGPoint(x: 0, y: 0.08)),
                XomoThemeSampleItem(component: .card, relativeOrigin: CGPoint(x: 0.34, y: 0.15)),
                XomoThemeSampleItem(component: .searchInput, relativeOrigin: CGPoint(x: 0.38, y: 0.39)),
                XomoThemeSampleItem(component: .selectInput, relativeOrigin: CGPoint(x: 0.38, y: 0.51)),
                XomoThemeSampleItem(component: .button, relativeOrigin: CGPoint(x: 0.38, y: 0.63))
            ]
        case .chakraForm:
            [
                XomoThemeSampleItem(component: .card, relativeOrigin: CGPoint(x: 0.28, y: 0.12)),
                XomoThemeSampleItem(component: .input, relativeOrigin: CGPoint(x: 0.34, y: 0.32)),
                XomoThemeSampleItem(component: .selectInput, relativeOrigin: CGPoint(x: 0.34, y: 0.44)),
                XomoThemeSampleItem(component: .checkbox, relativeOrigin: CGPoint(x: 0.34, y: 0.57)),
                XomoThemeSampleItem(component: .tag, relativeOrigin: CGPoint(x: 0.34, y: 0.66)),
                XomoThemeSampleItem(component: .button, relativeOrigin: CGPoint(x: 0.50, y: 0.64))
            ]
        case .radixSettings:
            [
                XomoThemeSampleItem(component: .topNavigation, relativeOrigin: CGPoint(x: 0, y: 0)),
                XomoThemeSampleItem(component: .card, relativeOrigin: CGPoint(x: 0.24, y: 0.16)),
                XomoThemeSampleItem(component: .listRow, relativeOrigin: CGPoint(x: 0.30, y: 0.38)),
                XomoThemeSampleItem(component: .selectInput, relativeOrigin: CGPoint(x: 0.33, y: 0.52)),
                XomoThemeSampleItem(component: .toggle, relativeOrigin: CGPoint(x: 0.62, y: 0.55)),
                XomoThemeSampleItem(component: .secondaryButton, relativeOrigin: CGPoint(x: 0.44, y: 0.68))
            ]
        }
    }

    private func xomoThemeSampleOrigin(for relativeOrigin: CGPoint) -> CGPoint {
        CGPoint(
            x: document.canvasSize.width * relativeOrigin.x,
            y: document.canvasSize.height * relativeOrigin.y
        )
    }

    private func applyXomoTheme(
        _ tokens: XomoComponentThemeTokens,
        to layer: inout ImageEditorLayer,
        component: XomoComponentKind
    ) {
        switch component {
        case .button, .secondaryButton, .ghostButton, .iconButton:
            let variant = XomoButtonVariant(component: component)
            if layer.isShape {
                updateXomoShape(&layer, fillColor: variant.fillColor(tokens: tokens), strokeColor: variant.strokeColor(tokens: tokens))
            } else if layer.isText {
                updateXomoText(&layer, color: variant.labelColor(tokens: tokens))
            }
        case .input, .searchInput, .textArea, .selectInput:
            if layer.isShape {
                updateXomoShape(&layer, fillColor: tokens.surface, strokeColor: tokens.border)
            } else if layer.isText {
                updateXomoText(&layer, color: tokens.secondaryText)
            }
        case .card:
            if layer.isShape {
                updateXomoShape(&layer, fillColor: tokens.surface, strokeColor: tokens.border)
            } else if let textContent = layer.textContent {
                updateXomoText(&layer, color: textContent.isBold ? tokens.primaryText : tokens.secondaryText)
            }
        default:
            if layer.isShape {
                updateXomoShape(&layer, fillColor: tokens.subtleSurface, strokeColor: tokens.border)
            } else if let textContent = layer.textContent {
                updateXomoText(&layer, color: textContent.isBold ? tokens.primaryText : tokens.secondaryText)
            }
        }
    }

    private func updateXomoShape(_ layer: inout ImageEditorLayer, fillColor: NSColor, strokeColor: NSColor) {
        guard var content = layer.shapeContent else { return }
        content.fillColor = fillColor
        content.strokeColor = strokeColor
        layer.kind = .shape(content)
    }

    private func updateXomoText(_ layer: inout ImageEditorLayer, color: NSColor) {
        guard var content = layer.textContent else { return }
        content.color = color
        layer.kind = .text(content)
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
