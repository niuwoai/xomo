import AppKit
import SwiftUI

struct XomoFigmaLinkImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ImageEditorViewModel
    @State private var draft = XomoFigmaLinkImportDraft()
    @State private var transientMessageKey: String?
    @State private var nodeIDDraft = ""
    @State private var nodeSelectionMessageKey: String?
    @State private var didImportNodePlan = false
    @StateObject private var metadataController = XomoFigmaAuthorizedMetadataController()
    @StateObject private var nodeImportController = XomoFigmaNodeImportController()
    let placementCenter: CGPoint?

    init(
        viewModel: ImageEditorViewModel,
        initialLink: String? = nil,
        placementCenter: CGPoint? = nil
    ) {
        self.viewModel = viewModel
        self.placementCenter = placementCenter
        _draft = State(initialValue: XomoFigmaLinkImportDraft(input: initialLink ?? ""))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    inputSection
                    previewSection
                    if let preview = draft.preview {
                        if preview.plannedImportScope == .previewOnly {
                            statusCard(
                                symbol: "eye",
                                messageKey: "xomo.figma.scope.previewOnly",
                                color: Color(nsColor: ImageEditorTheme.mutedText)
                            )
                        } else {
                            authorizedMetadataSection(preview)
                            authorizedNodeImportSection(preview)
                        }
                    }
                    securityNotice
                }
                .padding(20)
            }
            Divider().overlay(Color(nsColor: ImageEditorTheme.border))
            footer.padding(16)
        }
        .frame(width: 640, height: 700)
        .background(Color(nsColor: ImageEditorTheme.panel))
        .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
        .onAppear {
            metadataController.refreshCredentialState()
        }
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
                HStack(spacing: 8) {
                    Text(L10n.text("xomo.figma.preview.canonicalURL"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    Spacer()
                    Button(L10n.text("xomo.figma.action.useCanonicalURL")) {
                        useCanonicalURL()
                    }
                    .buttonStyle(.borderless)
                    .focusable(false)
                    .disabled(!draft.canUseCanonicalURL)
                    .accessibilityIdentifier("xomo-figma-use-canonical-link")
                }
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

    private func authorizedMetadataSection(_ preview: XomoFigmaLinkPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Color.accentColor)
                Text(L10n.text("xomo.figma.metadata.title"))
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text(L10n.text("xomo.figma.metadata.readOnly"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }

            Text(L10n.text("xomo.figma.metadata.scopeNotice"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .fixedSize(horizontal: false, vertical: true)

            if metadataController.hasStoredCredential {
                storedCredentialControls(preview)
            } else {
                newCredentialControls(preview)
            }

            authorizedMetadataStateView
        }
        .padding(12)
        .background(Color(nsColor: ImageEditorTheme.panelRaised).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func newCredentialControls(_ preview: XomoFigmaLinkPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField(
                L10n.text("xomo.figma.metadata.tokenPlaceholder"),
                text: $metadataController.tokenDraft
            )
            .textFieldStyle(.plain)
            .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Color.black.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityIdentifier("xomo-figma-personal-token")

            HStack {
                Text(L10n.text("xomo.figma.metadata.tokenStorageNotice"))
                    .font(.system(size: 10))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                Spacer()
                Button(L10n.text("xomo.figma.metadata.connectAndRead")) {
                    Task {
                        await metadataController.connectAndFetch(preview: preview)
                    }
                }
                .buttonStyle(.borderedProminent)
                .focusable(false)
                .disabled(metadataController.tokenDraft.isEmpty || metadataController.isLoading)
                .accessibilityIdentifier("xomo-figma-connect-and-read")
            }
        }
    }

    private func storedCredentialControls(_ preview: XomoFigmaLinkPreview) -> some View {
        HStack(spacing: 8) {
            Label(
                L10n.text("xomo.figma.metadata.connected"),
                systemImage: "checkmark.circle.fill"
            )
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.green)
            Spacer()
            Button(L10n.text("xomo.figma.metadata.read")) {
                Task {
                    await metadataController.fetchMetadata(preview: preview)
                }
            }
            .buttonStyle(.borderedProminent)
            .focusable(false)
            .disabled(metadataController.isLoading)
            .accessibilityIdentifier("xomo-figma-read-metadata")
            Button(L10n.text("xomo.figma.metadata.disconnect")) {
                metadataController.disconnect()
                nodeImportController.clear()
                didImportNodePlan = false
            }
            .buttonStyle(.bordered)
            .focusable(false)
            .accessibilityIdentifier("xomo-figma-disconnect")
        }
    }

    @ViewBuilder
    private var authorizedMetadataStateView: some View {
        switch metadataController.state {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(L10n.text("xomo.figma.metadata.loading"))
                    .font(.system(size: 10, weight: .medium))
            }
        case let .failed(error):
            Label(L10n.text(error.localizationKey), systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        case let .loaded(metadata):
            officialMetadataGrid(metadata)
        }
    }

    private func officialMetadataGrid(_ metadata: XomoFigmaOfficialFileMetadata) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
            metadataRow("xomo.figma.metadata.fileName", metadata.name)
            metadataRow("xomo.figma.metadata.folderName", metadataValue(metadata.folderName))
            metadataRow("xomo.figma.metadata.editorType", metadataValue(metadata.editorType))
            metadataRow("xomo.figma.metadata.version", metadataValue(metadata.version))
            metadataRow("xomo.figma.metadata.role", metadataValue(metadata.role))
            metadataRow("xomo.figma.metadata.linkAccess", metadataValue(metadata.linkAccess))
            metadataRow("xomo.figma.metadata.lastTouched", metadataValue(metadata.lastTouchedAt))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityIdentifier("xomo-figma-official-metadata")
    }

    private func metadataRow(_ titleKey: String, _ value: String) -> some View {
        GridRow {
            Text(L10n.text(titleKey))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            Text(value)
                .font(.system(size: 10, weight: .medium).monospaced())
                .lineLimit(1)
        }
    }

    private func metadataValue(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return L10n.text("xomo.figma.value.none")
        }
        return value
    }

    private func authorizedNodeImportSection(_ preview: XomoFigmaLinkPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "square.3.layers.3d")
                    .foregroundStyle(Color.accentColor)
                Text(L10n.text("xomo.figma.node.title"))
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text(L10n.text("xomo.figma.node.planOnly"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }

            Text(L10n.text("xomo.figma.node.scopeNotice"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                .fixedSize(horizontal: false, vertical: true)

            if preview.nodeID == nil {
                Label(
                    L10n.text("xomo.figma.node.selectionRequired"),
                    systemImage: "scope"
                )
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.orange)
            } else if !metadataController.hasStoredCredential {
                Label(
                    L10n.text("xomo.figma.node.credentialRequired"),
                    systemImage: "lock"
                )
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }

            nodeSelectionControls

            HStack {
                Spacer()
                Button(L10n.text("xomo.figma.node.readPlan")) {
                    didImportNodePlan = false
                    Task {
                        await nodeImportController.fetchPlan(preview: preview)
                    }
                }
                .buttonStyle(.borderedProminent)
                .focusable(false)
                .disabled(
                    preview.nodeID == nil
                        || !metadataController.hasStoredCredential
                        || nodeImportController.isLoading
                )
                .accessibilityIdentifier("xomo-figma-read-node-plan")
            }

            nodeImportStateView
        }
        .padding(12)
        .background(Color(nsColor: ImageEditorTheme.panelRaised).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var nodeSelectionControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("xomo.figma.node.nodeIDInputLabel"))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            HStack(spacing: 8) {
                TextField(
                    "",
                    text: $nodeIDDraft,
                    prompt: Text(L10n.text("xomo.figma.node.nodeIDInputPlaceholder"))
                        .foregroundColor(Color(nsColor: ImageEditorTheme.mutedText))
                )
                .textFieldStyle(.plain)
                .foregroundStyle(Color(nsColor: ImageEditorTheme.text))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Color.black.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .submitLabel(.done)
                .onSubmit {
                    guard canApplyNodeSelection else { return }
                    applyNodeSelection()
                }
                .accessibilityIdentifier("xomo-figma-node-id-input")

                Button(L10n.text("xomo.figma.node.useNodeID")) {
                    applyNodeSelection()
                }
                .buttonStyle(.bordered)
                .focusable(false)
                .disabled(!canApplyNodeSelection)
                .accessibilityIdentifier("xomo-figma-use-node-id")
            }

            if let nodeSelectionMessageKey {
                Text(L10n.text(nodeSelectionMessageKey))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(
                        nodeSelectionMessageKey == "xomo.figma.node.nodeIDInvalid"
                            ? Color.orange
                            : Color(nsColor: ImageEditorTheme.mutedText)
                    )
            }
        }
    }

    @ViewBuilder
    private var nodeImportStateView: some View {
        switch nodeImportController.state {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(L10n.text("xomo.figma.node.loading"))
                    .font(.system(size: 10, weight: .medium))
            }
        case let .failed(error):
            Label(L10n.text(error.localizationKey), systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        case let .loaded(plan):
            nodeImportPlanView(plan)
        }
    }

    private func nodeImportPlanView(_ plan: XomoFigmaNodeImportPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.format(
                "xomo.figma.node.summary",
                plan.items.count,
                plan.exactCount,
                plan.partialCount,
                plan.unsupportedCount
            ))
            .font(.system(size: 10, weight: .bold))

            ForEach(Array(plan.items.prefix(50))) { item in
                nodeImportPlanRow(item)
            }

            if plan.items.count > 50 {
                Text(L10n.format("xomo.figma.node.moreItems", plan.items.count - 50))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
            }

            HStack(spacing: 8) {
                if didImportNodePlan {
                    Label(
                        L10n.text("xomo.figma.node.imported"),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
                }
                Spacer()
                Button(L10n.text("xomo.figma.node.importLayers")) {
                    didImportNodePlan = viewModel.importFigmaNodePlan(
                        plan,
                        centeredAt: placementCenter
                    )
                }
                .buttonStyle(.borderedProminent)
                .focusable(false)
                .disabled(didImportNodePlan || plan.mappableCount == 0)
                .accessibilityIdentifier("xomo-figma-import-node-plan")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityIdentifier("xomo-figma-node-import-plan")
    }

    private func nodeImportPlanRow(_ item: XomoFigmaNodeImportItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Color.clear.frame(width: CGFloat(min(item.depth, 8)) * 10, height: 1)
                Image(systemName: nodeImportSymbol(item))
                    .foregroundStyle(nodeImportColor(item.fidelity))
                    .frame(width: 14)
                Text(item.sourceName)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                Text(item.sourceType)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                Spacer(minLength: 4)
                Text(item.targetKind.map { L10n.text($0.localizationKey) } ?? "—")
                    .font(.system(size: 9, weight: .medium))
            }
            if !item.issues.isEmpty {
                Text(item.issues.map { L10n.text($0.localizationKey) }.joined(separator: " · "))
                    .font(.system(size: 9))
                    .foregroundStyle(Color(nsColor: ImageEditorTheme.mutedText))
                    .lineLimit(2)
                    .padding(.leading, CGFloat(min(item.depth, 8)) * 10 + 20)
            }
        }
    }

    private func nodeImportSymbol(_ item: XomoFigmaNodeImportItem) -> String {
        switch item.fidelity {
        case .exact: "checkmark.circle.fill"
        case .partial: "exclamationmark.circle.fill"
        case .unsupported: "xmark.circle.fill"
        }
    }

    private func nodeImportColor(_ fidelity: XomoFigmaNodeMappingFidelity) -> Color {
        switch fidelity {
        case .exact: .green
        case .partial: .orange
        case .unsupported: .red
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
            Button(L10n.text("xomo.figma.action.openInFigma")) {
                openCanonicalURLInFigma()
            }
            .buttonStyle(.bordered)
            .focusable(false)
            .disabled(draft.canonicalURLForExternalOpen == nil)
            .accessibilityIdentifier("xomo-figma-open-canonical-link")

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
            nodeIDDraft = ""
            nodeSelectionMessageKey = nil
            didImportNodePlan = false
            metadataController.clearMetadata()
            nodeImportController.clear()
            draft.updateInput(value)
        }
    }

    private var canApplyNodeSelection: Bool {
        !nodeIDDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func pasteLink() {
        let route = XomoFigmaClipboardInputPolicy.resolve(
            clipboardText: NSPasteboard.general.string(forType: .string),
            clipboardURLString: NSPasteboard.general.string(forType: .URL),
            clipboardRichLinkTargets: XomoFigmaRichClipboardLinkExtractor.targets(from: .general)
        )
        let value: String
        switch route {
        case let .input(input):
            value = input
        case .empty:
            transientMessageKey = "xomo.figma.clipboard.empty"
            return
        case .rejected:
            transientMessageKey = "xomo.figma.clipboard.untrusted"
            return
        }
        transientMessageKey = nil
        nodeIDDraft = ""
        nodeSelectionMessageKey = nil
        didImportNodePlan = false
        metadataController.clearMetadata()
        nodeImportController.clear()
        draft.updateInput(value)
    }

    private func copyCanonicalURL() {
        guard XomoFigmaClipboardWriter.writeCanonicalURL(draft.preview?.canonicalURL) else { return }
        transientMessageKey = "xomo.figma.clipboard.copied"
    }

    private func openCanonicalURLInFigma() {
        guard let canonicalURL = draft.canonicalURLForExternalOpen else { return }
        guard NSWorkspace.shared.open(canonicalURL) else {
            transientMessageKey = "xomo.figma.message.openFailed"
            return
        }
        transientMessageKey = nil
    }

    private func useCanonicalURL() {
        guard draft.useCanonicalURL() else { return }
        transientMessageKey = "xomo.figma.message.canonicalURLApplied"
    }

    private func applyNodeSelection() {
        let previousNodeID = draft.preview?.nodeID
        guard draft.retarget(toNodeInput: nodeIDDraft) else {
            nodeSelectionMessageKey = "xomo.figma.node.nodeIDInvalid"
            return
        }
        nodeIDDraft = ""
        nodeSelectionMessageKey = "xomo.figma.node.nodeIDApplied"
        if draft.preview?.nodeID != previousNodeID {
            didImportNodePlan = false
            nodeImportController.clear()
        }
    }
}
