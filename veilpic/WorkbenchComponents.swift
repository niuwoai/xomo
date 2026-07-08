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

struct IntakeQuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(Circle())

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.inkText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.horizontal, 6)
            .background(Color.white.opacity(0.62))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppTheme.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(PressableWorkbenchButtonStyle())
        .help(title)
    }
}

struct IllustratedWorkbenchPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("WorkbenchBackdrop")
                .resizable()
                .scaledToFill()
                .opacity(0.72)
                .allowsHitTesting(false)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.68),
                    Color.white.opacity(0.36),
                    AppTheme.waveLight.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            content
                .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppTheme.accent.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: AppTheme.cardShadow, radius: 14, x: 0, y: 6)
    }
}

struct WorkbenchActionButton: View {
    enum Style {
        case primary
        case secondary
    }

    let icon: String
    let title: String
    let style: Style
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(iconBackground)
                    .clipShape(Circle())

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 62)
            .padding(.horizontal, 8)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            }
            .shadow(color: shadow, radius: style == .primary ? 11 : 5, x: 0, y: style == .primary ? 5 : 2)
            .opacity(isDisabled ? 0.46 : 1)
        }
        .buttonStyle(PressableWorkbenchButtonStyle())
        .disabled(isDisabled)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            AppTheme.accentGradient
        case .secondary:
            Color.white.opacity(0.70)
        }
    }

    @ViewBuilder
    private var iconBackground: some View {
        switch style {
        case .primary:
            Color.white.opacity(0.18)
        case .secondary:
            AppTheme.accent.opacity(0.12)
        }
    }

    private var foreground: Color {
        switch style {
        case .primary:
            .white
        case .secondary:
            AppTheme.accent
        }
    }

    private var border: Color {
        switch style {
        case .primary:
            Color.white.opacity(0.20)
        case .secondary:
            AppTheme.hairline
        }
    }

    private var shadow: Color {
        switch style {
        case .primary:
            AppTheme.accent.opacity(0.30)
        case .secondary:
            AppTheme.cardShadow.opacity(0.65)
        }
    }
}

private struct PressableWorkbenchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct WorkbenchPreviewCard: View {
    let item: ImageWorkspaceItem
    let template: PostProcessTemplate
    let imageData: Data?
    var onEdit: (() -> Void)?

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
                Button {
                    onEdit?()
                } label: {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(canEdit ? AppTheme.accent : Color.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(canEdit ? 0.72 : 0.36))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(AppTheme.hairline, lineWidth: 1)
                        }
                }
                .buttonStyle(PressableWorkbenchButtonStyle())
                .disabled(!canEdit)
                .help(L10n.text("workbench.preview.edit"))
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

    private var canEdit: Bool {
        imageData != nil && onEdit != nil
    }
}

struct PostProcessToolbarButton: View {
    let template: PostProcessTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: template.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : AppTheme.accent)
                .frame(width: 34, height: 34)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(isSelected ? Color.white.opacity(0.22) : AppTheme.hairline, lineWidth: 1)
                }
                .shadow(color: isSelected ? AppTheme.accent.opacity(0.24) : .clear, radius: 7, x: 0, y: 3)
        }
        .buttonStyle(PressableWorkbenchButtonStyle())
        .help(template.title)
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            AppTheme.accentGradient
        } else {
            Color.white.opacity(0.72)
        }
    }
}

struct TemplatePillButton: View {
    let template: PostProcessTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: template.symbolName)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(isSelected ? Color.white.opacity(0.18) : AppTheme.accent.opacity(0.12))
                    .clipShape(Circle())
                Text(template.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? .white : AppTheme.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.24) : AppTheme.hairline, lineWidth: 1)
            }
            .shadow(color: isSelected ? AppTheme.accent.opacity(0.22) : AppTheme.cardShadow.opacity(0.55), radius: isSelected ? 9 : 5, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            AppTheme.accentGradient
        } else {
            Color.white.opacity(0.68)
        }
    }
}
