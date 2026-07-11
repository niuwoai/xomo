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

    static let starterItems: [Self] = [
        Self(id: "button", titleKey: "xomo.componentPreview.button", symbolName: "rectangle.inset.filled"),
        Self(id: "input", titleKey: "xomo.componentPreview.input", symbolName: "text.cursor"),
        Self(id: "card", titleKey: "xomo.componentPreview.card", symbolName: "rectangle.on.rectangle"),
        Self(id: "image", titleKey: "xomo.componentPreview.image", symbolName: "photo"),
        Self(id: "avatar", titleKey: "xomo.componentPreview.avatar", symbolName: "person.crop.circle"),
        Self(id: "icon", titleKey: "xomo.componentPreview.icon", symbolName: "sparkles")
    ]
}

struct XomoComponentLibraryPanel: View {
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
                    ForEach(XomoComponentLibraryPreviewItem.starterItems) { item in
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
        VStack(spacing: 7) {
            Image(systemName: item.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.selected))
            Text(L10n.text(item.titleKey))
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(Color(nsColor: ImageEditorTheme.panelRaised), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color(nsColor: ImageEditorTheme.border), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text(item.titleKey))
    }
}
