//
//  WorkbenchComponents.swift
//  veilpic
//
//  Created by Codex on 2026/6/30.
//

import SwiftUI

struct CompactWorkbenchButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.inkText)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .themedCard(cornerRadius: 11, fill: AppTheme.controlFill, shadow: false)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct WorkbenchPreviewCard: View {
    let item: ImageWorkspaceItem
    let template: PostProcessTemplate
    let imageData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("workbench.preview.title"))
                        .font(.headline)
                    Text("\(item.sourceName) · \(item.pixelSizeText) · \(template.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.50))

                if let imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 188)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppTheme.hairline, lineWidth: 1)
            }
        }
        .padding(12)
        .themedCard()
    }
}

struct TemplatePillButton: View {
    let template: PostProcessTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: template.symbolName)
                    .font(.headline)
                Text(template.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? .white : AppTheme.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isSelected ? AppTheme.accent : AppTheme.controlFill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? AppTheme.accent.opacity(0.15) : AppTheme.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
