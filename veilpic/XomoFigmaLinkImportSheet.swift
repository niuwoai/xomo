import AppKit
import SwiftUI

struct XomoFigmaLinkImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = XomoFigmaLinkImportDraft()
    @State private var transientMessageKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            inputSection
            previewSection
            securityNotice
            footer
        }
        .padding(20)
        .frame(width: 620)
        .background(Color(nsColor: ImageEditorTheme.panel))
        .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text("xomo.figma.preview.title"))
                    .font(.system(size: 17, weight: .bold))
                Text(L10n.text("xomo.figma.preview.subtitle"))
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }
            Spacer(minLength: 8)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(L10n.text("imageEditor.action.cancel"))
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L10n.text("xomo.figma.preview.inputLabel"))
                .font(.system(size: 11, weight: .semibold))
            HStack(spacing: 8) {
                TextField(
                    "",
                    text: inputBinding,
                    prompt: Text(L10n.text("xomo.figma.preview.inputPlaceholder"))
                        .foregroundColor(Color(nsColor: ImageEditorTheme.mutedText))
                )
                .textFieldStyle(.plain)
                .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(Color(nsColor: ImageEditorTheme.panelRaised))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .accessibilityIdentifier("xomo-figma-link-input")

                Button(L10n.text("xomo.figma.action.paste")) {
                    pasteLink()
                }
                .buttonStyle(.bordered)
                .focusable(false)
                .accessibilityIdentifier("xomo-figma-paste-link")
            }

            if let transientMessageKey {
                Text(L10n.text(transientMessageKey))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        switch draft.state {
        case .empty:
            statusCard(
                symbol: "link",
                messageKey: "xomo.figma.preview.empty",
                color: Color(nsColor: ImageEditorTheme.mutedText)
            )
        case let .invalid(error):
            statusCard(
                symbol: "exclamationmark.triangle.fill",
                messageKey: error.localizationKey,
                color: .orange
            )
        case let .valid(preview):
            validPreview(preview)
        }
    }

    private func statusCard(symbol: String, messageKey: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(L10n.text(messageKey))
                .font(.system(size: 11, weight: .medium))
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: ImageEditorTheme.panelRaised).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func validPreview(_ preview: XomoFigmaLinkPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Text(L10n.text("xomo.figma.preview.valid"))
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text(L10n.text(preview.authorizationState.localizationKey))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
                previewRow("xomo.figma.preview.resourceType", L10n.text(preview.resourceType.localizationKey))
                previewRow("xomo.figma.preview.fileName", preview.displayName)
                previewRow("xomo.figma.preview.fileKey", preview.fileKey)
                previewRow("xomo.figma.preview.nodeID", preview.nodeID ?? L10n.text("xomo.figma.value.none"))
                previewRow(
                    "xomo.figma.preview.startingPointNodeID",
                    preview.startingPointNodeID ?? L10n.text("xomo.figma.value.none")
                )
                previewRow("xomo.figma.preview.versionID", preview.versionID ?? L10n.text("xomo.figma.value.latest"))
                previewRow("xomo.figma.preview.plannedScope", L10n.text(preview.plannedImportScope.localizationKey))
                previewRow(
                    "xomo.figma.preview.cleanedParameters",
                    L10n.format("xomo.figma.preview.cleanedParametersValue", preview.discardedQueryItemCount)
                )
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.text("xomo.figma.preview.canonicalURL"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                Text(preview.canonicalURL.absoluteString)
                    .font(.system(size: 10, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(3)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .padding(12)
        .background(Color(nsColor: ImageEditorTheme.panelRaised).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityIdentifier("xomo-figma-link-preview")
    }

    private func previewRow(_ titleKey: String, _ value: String) -> some View {
        GridRow {
            Text(L10n.text(titleKey))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            Text(value)
                .font(.system(size: 10, weight: .medium).monospaced())
                .lineLimit(1)
        }
    }

    private var securityNotice: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "network.slash")
                .foregroundStyle(Color.accentColor)
            Text(L10n.text("xomo.figma.preview.securityNotice"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var footer: some View {
        HStack {
            Button(L10n.text("xomo.figma.action.copyCanonicalURL")) {
                copyCanonicalURL()
            }
            .buttonStyle(.bordered)
            .focusable(false)
            .disabled(!draft.canCopyCanonicalURL)
            .accessibilityIdentifier("xomo-figma-copy-canonical-link")

            Spacer()
            Button(L10n.text("imageEditor.action.cancel")) {
                dismiss()
            }
            .buttonStyle(.bordered)
            .focusable(false)
            Button(L10n.text("xomo.figma.action.done")) {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .focusable(false)
        }
    }

    private var inputBinding: Binding<String> {
        Binding {
            draft.input
        } set: { value in
            transientMessageKey = nil
            draft.updateInput(value)
        }
    }

    private func pasteLink() {
        guard let value = NSPasteboard.general.string(forType: .string), !value.isEmpty else {
            transientMessageKey = "xomo.figma.clipboard.empty"
            return
        }
        transientMessageKey = nil
        draft.updateInput(value)
    }

    private func copyCanonicalURL() {
        guard let canonicalURL = draft.preview?.canonicalURL.absoluteString else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(canonicalURL, forType: .string)
        transientMessageKey = "xomo.figma.clipboard.copied"
    }
}
