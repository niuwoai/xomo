//
//  XomoLeftSidebar.swift
//  veilpic
//

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

    static let foundationItems: [Self] = [
        Self(id: "input", titleKey: "xomo.componentPreview.input", symbolName: "text.cursor", component: .input),
        Self(id: "card", titleKey: "xomo.componentPreview.card", symbolName: "rectangle.on.rectangle", component: .card),
        Self(id: "image", titleKey: "xomo.componentPreview.image", symbolName: "photo", component: .image),
        Self(id: "avatar", titleKey: "xomo.componentPreview.avatar", symbolName: "person.crop.circle", component: .avatar),
        Self(id: "icon", titleKey: "xomo.componentPreview.icon", symbolName: "sparkles", component: .icon)
    ]
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

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 72), spacing: 8), count: 2),
                    spacing: 8
                ) {
                    ForEach(XomoComponentLibraryPreviewItem.buttonFamilyItems) { item in
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
        .accessibilityIdentifier("xomo-component-library")
    }

    private func componentPreview(_ item: XomoComponentLibraryPreviewItem) -> some View {
        Group {
            if let component = item.component {
                Button {
                    viewModel.insertXomoComponent(component)
                } label: {
                    componentPreviewLabel(item, isAvailable: true)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .draggable(component.rawValue)
                .accessibilityIdentifier("xomo-component-library-item-\(component.rawValue)")
                .help(L10n.text("xomo.componentLibrary.dragOrInsert"))
            } else {
                componentPreviewLabel(item, isAvailable: false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.text(item.titleKey))
            }
        }
    }

    private func componentPreviewLabel(_ item: XomoComponentLibraryPreviewItem, isAvailable: Bool) -> some View {
        VStack(spacing: 7) {
            Image(systemName: item.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(nsColor: isAvailable ? ImageEditorTheme.selected : ImageEditorTheme.mutedText))
            Text(L10n.text(item.titleKey))
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            if !isAvailable {
                Text(L10n.text("xomo.componentLibrary.comingSoon"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(Color(nsColor: ImageEditorTheme.panelRaised), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color(nsColor: ImageEditorTheme.border), lineWidth: 1)
        }
    }
}
