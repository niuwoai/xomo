//
//  XomoLeftSidebar.swift
//  veilpic
//

import AppKit
import SwiftUI

enum XomoLeftSidebarTab: String, CaseIterable, Identifiable {
    case tools
    case components

    var id: String { rawValue }

    var title: String {
        L10n.text("xomo.leftSidebar.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .tools:
            "wrench.and.screwdriver"
        case .components:
            "square.grid.2x2"
        }
    }
}

enum XomoWorkspaceInputMode: Equatable {
    case tool(ImageEditorTool)
    case componentLibrary(XomoComponentKind?)

    static func resolve(
        sidebarTab: XomoLeftSidebarTab,
        selectedTool: ImageEditorTool,
        selectedComponent: XomoComponentKind?
    ) -> Self {
        switch sidebarTab {
        case .tools:
            .tool(selectedTool)
        case .components:
            .componentLibrary(selectedComponent)
        }
    }
}

enum XomoComponentLibraryCursorEvent: CaseIterable {
    case modeActivated
    case pointerEntered
    case componentSelected
    case dragBegan
    case dropCompleted
}

enum XomoComponentLibraryCursorPolicy {
    /// Component browsing and placement use the ordinary system pointer.
    /// Contextual canvas cursors such as resize and rotate remain owned by the
    /// canvas resolver; every component-library lifecycle boundary returns to
    /// the arrow so an earlier drawing-tool cursor cannot leak across modes.
    static func restoreArrow(
        for _: XomoComponentLibraryCursorEvent,
        setCursor: (NSCursor) -> Void = { $0.set() }
    ) {
        setCursor(.arrow)
    }
}

private struct XomoComponentLibraryPreviewItem: Identifiable {
    let id: String
    let titleKey: String
    let symbolName: String
    let component: XomoComponentKind?

    static let buttonFamilyItems: [Self] = [
        Self(id: "button", titleKey: "xomo.componentPreview.button", symbolName: "rectangle.inset.filled", component: .button),
        Self(id: "secondaryButton", titleKey: "xomo.componentPreview.secondaryButton", symbolName: "rectangle", component: .secondaryButton),
        Self(id: "ghostButton", titleKey: "xomo.componentPreview.ghostButton", symbolName: "text.badge.plus", component: .ghostButton),
        Self(id: "iconButton", titleKey: "xomo.componentPreview.iconButton", symbolName: "plus.circle", component: .iconButton)
    ]

    static let formItems: [Self] = [
        Self(id: "input", titleKey: "xomo.componentPreview.input", symbolName: "text.cursor", component: .input),
        Self(id: "searchInput", titleKey: "xomo.componentPreview.searchInput", symbolName: "magnifyingglass", component: .searchInput),
        Self(id: "textArea", titleKey: "xomo.componentPreview.textArea", symbolName: "text.alignleft", component: .textArea),
        Self(id: "selectInput", titleKey: "xomo.componentPreview.selectInput", symbolName: "chevron.up.chevron.down", component: .selectInput)
    ]

    static let selectionItems: [Self] = [
        Self(id: "toggle", titleKey: "xomo.componentPreview.toggle", symbolName: "switch.2", component: .toggle),
        Self(id: "checkbox", titleKey: "xomo.componentPreview.checkbox", symbolName: "checkmark.square", component: .checkbox),
        Self(id: "tag", titleKey: "xomo.componentPreview.tag", symbolName: "tag", component: .tag),
        Self(id: "badge", titleKey: "xomo.componentPreview.badge", symbolName: "circlebadge", component: .badge)
    ]

    static let navigationItems: [Self] = [
        Self(id: "listRow", titleKey: "xomo.componentPreview.listRow", symbolName: "list.bullet", component: .listRow),
        Self(id: "topNavigation", titleKey: "xomo.componentPreview.topNavigation", symbolName: "rectangle.topthird.inset.filled", component: .topNavigation),
        Self(id: "sideNavigation", titleKey: "xomo.componentPreview.sideNavigation", symbolName: "rectangle.lefthalf.inset.filled", component: .sideNavigation),
        Self(id: "tabBar", titleKey: "xomo.componentPreview.tabBar", symbolName: "rectangle.3.group", component: .tabBar)
    ]

    static let contentItems: [Self] = [
        Self(id: "carouselCard", titleKey: "xomo.componentPreview.carouselCard", symbolName: "rectangle.stack", component: .carouselCard),
        Self(id: "emptyState", titleKey: "xomo.componentPreview.emptyState", symbolName: "tray", component: .emptyState)
    ]

    static let foundationItems: [Self] = [
        Self(id: "card", titleKey: "xomo.componentPreview.card", symbolName: "rectangle.on.rectangle", component: .card),
        Self(id: "image", titleKey: "xomo.componentPreview.image", symbolName: "photo", component: .image),
        Self(id: "avatar", titleKey: "xomo.componentPreview.avatar", symbolName: "person.crop.circle", component: .avatar),
        Self(id: "icon", titleKey: "xomo.componentPreview.icon", symbolName: "sparkles", component: .icon)
    ]
}

private struct XomoComponentThumbnail: View {
    let kind: XomoComponentKind
    let tokens: XomoComponentThemeTokens
    var displaySize: CGSize? = nil

    private var radius: CGFloat { min(10, max(2, tokens.cornerRadius * 0.55)) }

    var body: some View {
        ZStack {
            switch kind {
            case .button, .secondaryButton, .ghostButton:
                RoundedRectangle(cornerRadius: radius)
                    .fill(kind == .button ? Color(nsColor: tokens.accent) : Color(nsColor: tokens.surface))
                    .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color(nsColor: kind == .ghostButton ? .clear : tokens.accentBorder), lineWidth: 1))
                Capsule().fill(Color(nsColor: kind == .button ? tokens.onAccent : tokens.primaryText)).frame(width: 30, height: 3)
            case .iconButton:
                RoundedRectangle(cornerRadius: radius).fill(Color(nsColor: tokens.accent)).frame(width: 30, height: 30)
                Image(systemName: "plus").foregroundStyle(Color(nsColor: tokens.onAccent)).font(.system(size: 11, weight: .bold))
            case .input, .searchInput, .textArea, .selectInput:
                RoundedRectangle(cornerRadius: radius).fill(Color(nsColor: tokens.surface))
                    .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color(nsColor: tokens.border), lineWidth: 1))
                HStack(spacing: 5) {
                    if kind == .searchInput { Image(systemName: "magnifyingglass").font(.system(size: 8)) }
                    Capsule().fill(Color(nsColor: tokens.secondaryText).opacity(0.72)).frame(width: 34, height: 3)
                    Spacer()
                    if kind == .selectInput { Image(systemName: "chevron.down").font(.system(size: 7, weight: .bold)) }
                }.foregroundStyle(Color(nsColor: tokens.secondaryText)).padding(8)
            case .toggle:
                Capsule().fill(Color(nsColor: tokens.accent)).frame(width: 42, height: 22)
                    .overlay(Circle().fill(Color(nsColor: tokens.onAccent)).frame(width: 17, height: 17).offset(x: 9))
            case .checkbox:
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(nsColor: tokens.accent)).frame(width: 18, height: 18)
                        .overlay(Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundStyle(Color(nsColor: tokens.onAccent)))
                    Capsule().fill(Color(nsColor: tokens.primaryText)).frame(width: 28, height: 3)
                }
            case .tag, .badge:
                Capsule().fill(Color(nsColor: tokens.subtleSurface)).overlay(Capsule().stroke(Color(nsColor: tokens.border), lineWidth: 1))
                    .frame(width: kind == .badge ? 30 : 58, height: 24)
            case .card, .carouselCard, .emptyState:
                RoundedRectangle(cornerRadius: radius).fill(Color(nsColor: tokens.surface))
                    .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color(nsColor: tokens.border), lineWidth: 1))
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(Color(nsColor: tokens.accent).opacity(0.65)).frame(height: kind == .carouselCard ? 16 : 7)
                            Capsule().fill(Color(nsColor: tokens.primaryText)).frame(width: 34, height: 3)
                            Capsule().fill(Color(nsColor: tokens.secondaryText)).frame(width: 48, height: 3)
                        }.padding(6)
                    }
            case .listRow, .topNavigation, .sideNavigation, .tabBar:
                RoundedRectangle(cornerRadius: radius).fill(Color(nsColor: tokens.surface))
                    .overlay(alignment: kind == .sideNavigation ? .leading : .center) {
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { index in
                                Capsule().fill(Color(nsColor: index == 0 ? tokens.accent : tokens.secondaryText).opacity(index == 0 ? 1 : 0.55))
                                    .frame(width: index == 0 ? 24 : 14, height: 4)
                            }
                        }.padding(7)
                    }
            case .image:
                RoundedRectangle(cornerRadius: radius).fill(LinearGradient(colors: [Color(nsColor: tokens.accent), Color(nsColor: tokens.subtleSurface)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Image(systemName: "photo").foregroundStyle(Color(nsColor: tokens.onAccent)))
            case .avatar:
                Circle().fill(Color(nsColor: tokens.accent)).overlay(Image(systemName: "person.fill").foregroundStyle(Color(nsColor: tokens.onAccent)))
                    .frame(width: 34, height: 34)
            case .icon:
                Image(systemName: "sparkles").font(.system(size: 25, weight: .semibold)).foregroundStyle(Color(nsColor: tokens.accent))
            }
        }
        .xomoComponentThumbnailFrame(displaySize)
    }
}

private extension View {
    @ViewBuilder
    func xomoComponentThumbnailFrame(_ displaySize: CGSize?) -> some View {
        if let displaySize {
            frame(width: displaySize.width, height: displaySize.height)
        } else {
            frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38)
        }
    }
}

private struct XomoComponentDragPreview: View {
    let kind: XomoComponentKind
    let tokens: XomoComponentThemeTokens
    let displaySize: CGSize

    var body: some View {
        XomoComponentThumbnail(kind: kind, tokens: tokens, displaySize: displaySize)
            .overlay {
                outline
            }
            .frame(width: displaySize.width, height: displaySize.height)
    }

    @ViewBuilder
    private var outline: some View {
        let stroke = StrokeStyle(lineWidth: 1, dash: [5, 4])
        switch kind {
        case .avatar, .badge:
            Circle().stroke(Color.gray.opacity(0.74), style: stroke)
        case .toggle, .tag:
            Capsule().stroke(Color.gray.opacity(0.74), style: stroke)
        default:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.gray.opacity(0.74), style: stroke)
        }
    }
}

struct XomoComponentLibraryPanel: View {
    @ObservedObject var viewModel: ImageEditorViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Label(L10n.text("xomo.componentLibrary.title"), systemImage: "square.grid.2x2")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.text))

                Text(L10n.text("xomo.componentLibrary.subtitle"))
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .fixedSize(horizontal: false, vertical: true)

                Menu {
                    ForEach(XomoComponentTheme.allCases) { theme in
                        Button(theme.libraryTitle) {
                            viewModel.selectXomoComponentTheme(theme)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(viewModel.xomoComponentTheme.libraryTitle)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(nsColor: ImageEditorTheme.text))
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                    .background(
                        Color(nsColor: ImageEditorTheme.window).opacity(0.68),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color(nsColor: ImageEditorTheme.border).opacity(0.9), lineWidth: 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityIdentifier("xomo-component-theme-picker")
                .accessibilityLabel(L10n.text("xomo.theme.picker"))
                .accessibilityValue(viewModel.xomoComponentTheme.libraryTitle)

                Text(viewModel.xomoComponentTheme.librarySource.attribution)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("xomo-component-theme-attribution")

                HStack(spacing: 6) {
                    Button(L10n.text("xomo.theme.copyTokens")) {
                        viewModel.copyCurrentXomoThemeTokens()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .focusable(false)
                    .accessibilityIdentifier("xomo-component-theme-copy-tokens")

                    Button(L10n.text("xomo.theme.exportTokens")) {
                        viewModel.chooseXomoThemeTokenExportFile()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .focusable(false)
                    .accessibilityIdentifier("xomo-component-theme-export-tokens")
                }

                HStack(spacing: 6) {
                    Button(L10n.text("xomo.theme.importTokens")) {
                        viewModel.chooseXomoThemeTokenImportFile()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .focusable(false)
                    .accessibilityIdentifier("xomo-component-theme-import-tokens")

                    Button(L10n.text("xomo.theme.clearTokens")) {
                        viewModel.clearImportedXomoThemeTokens()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .focusable(false)
                    .disabled(!viewModel.hasLocalXomoThemeTokens)
                    .accessibilityIdentifier("xomo-component-theme-clear-tokens")
                }

                Button(L10n.text("xomo.theme.refreshTokens")) {
                    viewModel.refreshXomoThemeTokensInDocument()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .focusable(false)
                .disabled(!viewModel.canRefreshXomoThemeTokens)
                .accessibilityIdentifier("xomo-component-theme-refresh-tokens")

                HStack(spacing: 6) {
                    Button(L10n.text("xomo.theme.apply")) {
                        viewModel.applyXomoThemeToSelectedComponent()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .focusable(false)
                    .disabled(!viewModel.canApplyXomoThemeToSelectedComponent)
                    .accessibilityIdentifier("xomo-component-theme-apply")

                    Button(L10n.text("xomo.theme.keepLocal")) {
                        viewModel.toggleXomoThemeOverrideForSelectedLayers()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .focusable(false)
                    .disabled(!viewModel.canToggleSelectedXomoThemeOverride)
                    .accessibilityIdentifier("xomo-component-theme-keep-local")
                }

                Button(L10n.text("xomo.themeSample.insert")) {
                    viewModel.insertXomoThemeSample()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .focusable(false)
                .accessibilityIdentifier("xomo-component-theme-sample-insert")

                Divider().overlay(Color(nsColor: ImageEditorTheme.border))

                Text(L10n.text("xomo.instance.title"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                HStack(spacing: 6) {
                    Button(L10n.text("xomo.instance.makeMaster")) {
                        viewModel.setSelectedXomoComponentAsMaster()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .focusable(false)
                    .disabled(!viewModel.canSetSelectedXomoComponentAsMaster)
                    .accessibilityIdentifier("xomo-component-instance-make-master")

                    Button(L10n.text("xomo.instance.link")) {
                        viewModel.linkSelectedXomoComponentsToMaster()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .focusable(false)
                    .disabled(!viewModel.canLinkSelectedXomoComponentsToMaster)
                    .accessibilityIdentifier("xomo-component-instance-link")
                }

                HStack(spacing: 6) {
                    Button(L10n.text("xomo.instance.sync")) {
                        viewModel.syncSelectedXomoComponentMaster()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .focusable(false)
                    .disabled(!viewModel.canSyncSelectedXomoComponentMaster)
                    .accessibilityIdentifier("xomo-component-instance-sync")

                    Button(L10n.text("xomo.instance.detach")) {
                        viewModel.detachSelectedXomoComponentInstances()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .focusable(false)
                    .disabled(!viewModel.canDetachSelectedXomoComponentInstances)
                    .accessibilityIdentifier("xomo-component-instance-detach")
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 72), spacing: 8), count: 2),
                    spacing: 8
                ) {
                    ForEach(XomoComponentLibraryPreviewItem.buttonFamilyItems) { item in
                        componentPreview(item)
                    }
                }

                Text(L10n.text("xomo.componentLibrary.formSection"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 72), spacing: 8), count: 2),
                    spacing: 8
                ) {
                    ForEach(XomoComponentLibraryPreviewItem.formItems) { item in
                        componentPreview(item)
                    }
                }

                Text(L10n.text("xomo.componentLibrary.contentSection"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 72), spacing: 8), count: 2),
                    spacing: 8
                ) {
                    ForEach(XomoComponentLibraryPreviewItem.contentItems) { item in
                        componentPreview(item)
                    }
                }

                Text(L10n.text("xomo.componentLibrary.navigationSection"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 72), spacing: 8), count: 2),
                    spacing: 8
                ) {
                    ForEach(XomoComponentLibraryPreviewItem.navigationItems) { item in
                        componentPreview(item)
                    }
                }

                Text(L10n.text("xomo.componentLibrary.selectionSection"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 72), spacing: 8), count: 2),
                    spacing: 8
                ) {
                    ForEach(XomoComponentLibraryPreviewItem.selectionItems) { item in
                        componentPreview(item)
                    }
                }

                Text(L10n.text("xomo.componentLibrary.foundationSection"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 72), spacing: 8), count: 2),
                    spacing: 8
                ) {
                    ForEach(XomoComponentLibraryPreviewItem.foundationItems) { item in
                        componentPreview(item)
                    }
                }

                Divider().overlay(Color(nsColor: ImageEditorTheme.border))

                Text(L10n.text("xomo.componentLibrary.nextStep"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        }
        .overlay {
            ImageEditorCursorRectView(cursor: .arrow)
                .allowsHitTesting(false)
        }
        .onHover { isInside in
            guard isInside else { return }
            XomoComponentLibraryCursorPolicy.restoreArrow(for: .pointerEntered)
        }
        .accessibilityIdentifier("xomo-component-library")
    }

    private func componentPreview(_ item: XomoComponentLibraryPreviewItem) -> some View {
        Group {
            if let component = item.component {
                // A native Button and a native drag source on the same view
                // can leave AppKit's button tracking session alive when a
                // component drag finishes. The following toolbar click then
                // never reaches SwiftUI. Keep tapping and dragging as sibling
                // gestures on an ordinary hit-test view instead.
                componentPreviewLabel(item, isAvailable: true)
                .contentShape(Rectangle())
                .onTapGesture {
                    insertComponent(component)
                }
                .xomoDraggable(
                    component.rawValue,
                    onDragBegan: {
                        XomoComponentLibraryCursorPolicy.restoreArrow(for: .dragBegan)
                    }
                ) {
                    XomoComponentDragPreview(
                        kind: component,
                        tokens: viewModel.activeXomoComponentTokens,
                        displaySize: viewModel.xomoComponentDragPreviewSize(component)
                    )
                }
                .onHover { isInside in
                    guard isInside else { return }
                    XomoComponentLibraryCursorPolicy.restoreArrow(for: .pointerEntered)
                }
                .focusable(false)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    insertComponent(component)
                }
                .accessibilityIdentifier("xomo-component-library-item-\(component.rawValue)")
                .help(L10n.text("xomo.componentLibrary.dragOrInsert"))
            } else {
                componentPreviewLabel(item, isAvailable: false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.text(item.titleKey))
            }
        }
    }

    private func insertComponent(_ component: XomoComponentKind) {
        XomoComponentLibraryCursorPolicy.restoreArrow(for: .componentSelected)
        viewModel.insertXomoComponent(component)
        XomoComponentLibraryCursorPolicy.restoreArrow(for: .componentSelected)
    }

    private func componentPreviewLabel(_ item: XomoComponentLibraryPreviewItem, isAvailable: Bool) -> some View {
        let isSelected = item.component == viewModel.selectedXomoObjectKind
        return VStack(spacing: 6) {
            if let component = item.component {
                XomoComponentThumbnail(kind: component, tokens: viewModel.activeXomoComponentTokens)
            } else {
                Image(systemName: item.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .frame(height: 38)
            }
            Text(L10n.text(item.titleKey))
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            if !isAvailable {
                Text(L10n.text("xomo.componentLibrary.comingSoon"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, minHeight: 78)
        .background(
            isSelected
                ? Color(nsColor: ImageEditorTheme.selected).opacity(0.22)
                : Color(nsColor: ImageEditorTheme.panelRaised),
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(
                    isSelected
                        ? Color(nsColor: ImageEditorTheme.selected).opacity(0.92)
                        : Color(nsColor: ImageEditorTheme.border),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
        .shadow(
            color: isSelected ? Color(nsColor: ImageEditorTheme.selected).opacity(0.24) : .clear,
            radius: isSelected ? 5 : 0
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
