//
//  PanelComponents.swift
//  veilpic
//
//  Created by Codex on 2026/5/20.
//

import AppKit
import SwiftUI

struct ProviderBadge: View {
    let provider: StorageProviderKind

    var body: some View {
        Label(provider.shortTitle, systemImage: provider.symbolName)
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.12))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
    }
}

struct FeedbackBanner: View {
    let feedback: UserFeedback
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: feedback.kind.symbolName)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(feedback.title)
                    .font(.caption.weight(.semibold))
                Text(feedback.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("关闭提示")
        }
        .padding(10)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(tint.opacity(0.18))
        }
    }

    private var tint: Color {
        switch feedback.kind {
        case .success:
            .green
        case .warning:
            .orange
        case .error:
            .red
        case .progress:
            .blue
        }
    }
}

struct UploadProgressView: View {
    let phase: UploadPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(phase.title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int((phase.progress * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: phase.progress)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct MetricPill: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ConfigField: View {
    let title: String
    let icon: String
    @Binding var text: String
    var prompt = ""
    var isRequired = true

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                if isRequired {
                    Text("必填")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            TextField(prompt.isEmpty ? title : prompt, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct SecretConfigField: View {
    let title: String
    let icon: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("必填")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.orange)
            }
            SecureField(title, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct VariantSummaryRow: View {
    let variant: GeneratedImageVariant

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: variant.kind.symbolName)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(variant.kind.title)
                    .font(.caption.weight(.semibold))
                Text(variant.kind.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(variant.byteCountText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(9)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ImagePreviewCard: View {
    let title: String
    let subtitle: String
    let imageData: Data?
    let footer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(footer)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.windowBackgroundColor))
                if let imageData, let image = NSImage(data: imageData) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 32, weight: .medium))
                        Text("暂无预览")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.12))
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct HistoryPreviewCard: View {
    let item: UploadHistoryItem
    let copyPrimary: () -> Void
    let copyMarkdown: () -> Void
    let copyAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ImagePreviewCard(
                title: item.sourceName,
                subtitle: item.providerSummary,
                imageData: item.thumbnailData,
                footer: "\(item.links.count) 个链接"
            )

            HStack(spacing: 8) {
                Button(action: copyPrimary) {
                    Label("复制主链接", systemImage: "link")
                }
                .buttonStyle(.borderedProminent)

                Button(action: copyMarkdown) {
                    Label("Markdown", systemImage: "text.quote")
                }
                .buttonStyle(.bordered)

                Button(action: copyAll) {
                    Label("全部", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct HistoryItemRow: View {
    let item: UploadHistoryItem
    let isSelected: Bool
    let select: () -> Void
    let copy: () -> Void
    let remove: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                thumbnail

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.sourceName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(item.createdAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(item.primaryURL?.absoluteString ?? item.providerSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button(action: copy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("复制主链接")

                Button(action: remove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("移除本地历史")
            }
            .padding(9)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.28) : Color.clear)
            }
        }
        .buttonStyle(.plain)
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.windowBackgroundColor))
            if let data = item.thumbnailData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct LinkRow: View {
    let kind: ImageVariantKind
    let url: URL
    let copy: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: kind.symbolName)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title)
                    .font(.caption.weight(.semibold))
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button(action: copy) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("复制链接")
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
