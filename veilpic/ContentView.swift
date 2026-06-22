//
//  ContentView.swift
//  veilpic
//
//  Created by rocky on 2026/5/19.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel: MenuBarUploadViewModel

    init(viewModel: MenuBarUploadViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        MenuBarPanelView(viewModel: viewModel)
            .frame(width: 440, height: 520)
    }
}

struct MainWindowView: View {
    @StateObject private var viewModel: MenuBarUploadViewModel

    init(viewModel: MenuBarUploadViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        MenuBarPanelView(viewModel: viewModel)
            .frame(minWidth: 560, minHeight: 560)
    }
}

struct StorageSettingsView: View {
    @ObservedObject var viewModel: MenuBarUploadViewModel
    @StateObject private var launchAtLogin = LaunchAtLoginSettings()
    @ObservedObject private var dockVisibility = DockVisibilitySettings.shared
    let mode: SettingsPresentationMode

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsHeader

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if mode == .onboarding {
                        onboardingSteps
                    }
                    configurationStatus
                    providerSelector
                    credentialModeSelector
                    configurationFields
                    uploadBehaviorSection
                    launchAtLoginSection
                    dockVisibilitySection
                    firstRunNote
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            settingsFooter
        }
        .frame(width: 560, height: 620)
    }

    private var settingsHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.accentColor.opacity(0.12))
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(mode == .onboarding ? L10n.text("settings.title.onboarding") : L10n.text("settings.title"))
                    .font(.title2.weight(.semibold))
                Text(L10n.text("settings.subtitle"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(22)
    }

    private var onboardingSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("onboarding.title"))
                .font(.headline)

            HStack(alignment: .top, spacing: 10) {
                OnboardingStepView(
                    number: 1,
                    title: L10n.text("onboarding.step.storage.title"),
                    message: L10n.text("onboarding.step.storage.message"),
                    isDone: true,
                    icon: "externaldrive.connected.to.line.below"
                )

                OnboardingStepView(
                    number: 2,
                    title: L10n.text("onboarding.step.config.title"),
                    message: viewModel.profile.missingFields.isEmpty ? L10n.text("onboarding.step.config.done") : L10n.format("onboarding.step.config.missing", viewModel.missingConfigurationText),
                    isDone: viewModel.profile.isReadyForUpload,
                    icon: "key.horizontal"
                )

                OnboardingStepView(
                    number: 3,
                    title: L10n.text("onboarding.step.menubar.title"),
                    message: L10n.text("onboarding.step.menubar.message"),
                    isDone: viewModel.profile.isReadyForUpload,
                    icon: "menubar.rectangle"
                )
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var configurationStatus: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(viewModel.configurationSummary)
                    .font(.headline)
                Spacer()
                ProviderBadge(provider: viewModel.profile.provider)
            }

            ProgressView(value: viewModel.configurationProgress)

            if viewModel.profile.missingFields.isEmpty {
                Label(L10n.text("settings.config.complete"), systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Label(L10n.format("settings.config.missing", viewModel.missingConfigurationText), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var providerSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("settings.provider"))
                .font(.headline)

            Picker(L10n.text("settings.provider"), selection: $viewModel.profile.provider) {
                ForEach(StorageProviderKind.allCases) { provider in
                    Label(provider.title, systemImage: provider.symbolName)
                        .tag(provider)
                }
            }
            .pickerStyle(.menu)

            Text(viewModel.profile.provider.configurationNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var credentialModeSelector: some View {
        if viewModel.profile.provider.supportsTemporaryCredentials {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("settings.credentialMode"))
                    .font(.headline)

                Picker(L10n.text("settings.credentialMode"), selection: $viewModel.profile.credentialMode) {
                    ForEach(StorageCredentialMode.allCases) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(viewModel.profile.credentialMode.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var configurationFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("settings.connectionInfo"))
                .font(.headline)

            ConfigField(title: L10n.text("field.bucket"), icon: "shippingbox", text: $viewModel.profile.bucket)
            ConfigField(title: L10n.text("field.region"), icon: "map", text: $viewModel.profile.region, prompt: viewModel.profile.provider.regionPlaceholder, isRequired: false)
            ConfigField(title: L10n.text("field.endpoint"), icon: "network", text: $viewModel.profile.endpoint, prompt: viewModel.profile.provider.endpointPlaceholder)
            ConfigField(title: L10n.text("field.cdnDomain"), icon: "globe", text: $viewModel.profile.cdnDomain, prompt: "https://img.example.com", isRequired: viewModel.profile.provider == .qiniuKodo)
            ConfigField(title: L10n.text("field.objectPrefix"), icon: "folder", text: $viewModel.profile.objectPrefix, prompt: "veilpic", isRequired: false)
            ConfigField(title: viewModel.profile.provider.accessKeyLabel, icon: "key", text: $viewModel.profile.accessKeyId)
            SecretConfigField(title: viewModel.profile.provider.secretKeyLabel, icon: "lock", text: $viewModel.profile.accessKeySecret)

            if viewModel.profile.provider.supportsTemporaryCredentials, viewModel.profile.credentialMode == .temporary {
                SecretConfigField(title: L10n.text("field.sessionToken"), icon: "ticket", text: $viewModel.profile.sessionToken)
            }
        }
    }

    private var dockVisibilitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $dockVisibility.hideDockIcon) {
                Label(L10n.text("settings.dockVisibility.title"), systemImage: "dock.rectangle")
                    .font(.headline)
            }

            Text(L10n.text("settings.dockVisibility.note"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )
            ) {
                Label(L10n.text("settings.launchAtLogin.title"), systemImage: "power")
                    .font(.headline)
            }

            Text(L10n.text("settings.launchAtLogin.note"))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let errorMessage = launchAtLogin.errorMessage {
                Label(L10n.format("settings.launchAtLogin.error", errorMessage), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            launchAtLogin.refresh()
        }
    }

    private var uploadBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("settings.uploadBehavior"))
                .font(.headline)

            Toggle(isOn: $viewModel.profile.automaticallyCopyAfterUpload) {
                Label(L10n.text("settings.autoCopy.title"), systemImage: "doc.on.clipboard")
                    .font(.caption.weight(.semibold))
            }

            Picker(L10n.text("settings.autoCopy.variant"), selection: $viewModel.profile.automaticCopyVariant) {
                ForEach(ImageVariantKind.allCases) { kind in
                    Label(kind.title, systemImage: kind.symbolName)
                        .tag(kind)
                }
            }
            .pickerStyle(.menu)
            .disabled(!viewModel.profile.automaticallyCopyAfterUpload)

            Text(L10n.text("settings.autoCopy.note"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var firstRunNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.text("settings.usage.title"), systemImage: "menubar.rectangle")
                .font(.headline)
            Text(L10n.text("settings.usage.message"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var settingsFooter: some View {
        HStack {
            Text(L10n.format("app.version", AppVersion.current))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(L10n.text("button.done")) {
                SettingsWindowPresenter.shared.close()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.profile.isReadyForUpload)
        }
        .padding(16)
    }
}

struct MenuBarPanelView: View {
    @ObservedObject var viewModel: MenuBarUploadViewModel
    @State private var selectedSection: PanelSection = .upload

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                header
                sectionPicker
                content
                footer
            }
            .padding(16)

            if let feedback = viewModel.feedback {
                FeedbackToast(feedback: feedback, dismiss: viewModel.dismissFeedback)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 50)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: feedback.id) {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        viewModel.dismissFeedback()
                    }
            }
        }
        .animation(.snappy(duration: 0.2), value: viewModel.feedback)
        .onChange(of: viewModel.suggestedSection) { _, section in
            guard let section else { return }
            selectedSection = section
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.12))
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text("app.name"))
                    .font(.title2.weight(.semibold))
                Text(viewModel.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if viewModel.isUploading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    SettingsWindowPresenter.shared.openFromMenuBar(mode: .settings)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.text("help.openSettings"))
            }
        }
    }

    private var sectionPicker: some View {
        Picker(L10n.text("panel.picker"), selection: $selectedSection) {
            ForEach(PanelSection.allCases) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if viewModel.isUploading || viewModel.phase != .idle {
                    UploadProgressView(phase: viewModel.phase, stats: viewModel.uploadStats)
                }

                switch selectedSection {
                case .upload:
                    uploadSection
                case .links:
                    linksSection
                case .history:
                    historySection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
    }

    private var uploadSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !viewModel.profile.isReadyForUpload {
                configurationPrompt
            }
            dropZone
            uploadQuickStats
            currentImagePreview
            variantPreview
            latestLinkPreview
        }
    }

    private var configurationPrompt: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "externaldrive.badge.gearshape")
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text("upload.configPrompt.title"))
                    .font(.caption.weight(.semibold))
                Text(L10n.text("upload.configPrompt.message"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                SettingsWindowPresenter.shared.openFromMenuBar(mode: .onboarding)
            } label: {
                Label(L10n.text("button.settings"), systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.bordered)
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.orange.opacity(0.2))
        }
    }

    private var dropZone: some View {
        VStack(spacing: 11) {
            Image(systemName: viewModel.isDropTargeted ? "arrow.down.circle.fill" : "photo.badge.plus")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(viewModel.isDropTargeted ? .blue : .secondary)

            Text(viewModel.isDropTargeted ? L10n.text("upload.drop.release") : L10n.text("upload.drop.idle"))
                .font(.headline)

            Text(L10n.text("upload.drop.message"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Button {
                viewModel.uploadFromClipboard()
            } label: {
                Label(viewModel.isUploading ? L10n.text("button.uploading") : L10n.text("button.uploadClipboard"), systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack(spacing: 8) {
                Button {
                    viewModel.chooseImageFiles()
                } label: {
                    Label(L10n.text("button.chooseImages"), systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }

                Button {
                    viewModel.chooseImageDirectory()
                } label: {
                    Label(L10n.text("button.chooseFolder"), systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(viewModel.isDropTargeted ? Color.blue.opacity(0.12) : Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(viewModel.isDropTargeted ? Color.blue : Color.secondary.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [6]))
        }
        .onDrop(
            of: [UTType.image.identifier, UTType.fileURL.identifier],
            isTargeted: $viewModel.isDropTargeted,
            perform: viewModel.handleDrop
        )
    }

    private var uploadQuickStats: some View {
        HStack(spacing: 10) {
            MetricPill(title: L10n.text("metric.provider"), value: viewModel.profile.provider.shortTitle, icon: viewModel.profile.provider.symbolName)
            MetricPill(title: L10n.text("metric.path"), value: viewModel.profile.objectPrefix.isEmpty ? L10n.text("metric.dateFolder") : viewModel.profile.objectPrefix, icon: "folder")
            MetricPill(title: L10n.text("metric.config"), value: "\(Int((viewModel.configurationProgress * 100).rounded()))%", icon: "checkmark.seal")
        }
    }

    @ViewBuilder
    private var currentImagePreview: some View {
        if let variant = previewVariant {
            ImagePreviewCard(
                title: L10n.text("preview.title"),
                subtitle: L10n.text("preview.subtitle"),
                imageData: variant.data,
                footer: variant.byteCountText
            )
        }
    }

    @ViewBuilder
    private var variantPreview: some View {
        if !viewModel.generatedVariants.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("variants.generated"))
                    .font(.headline)
                ForEach(viewModel.generatedVariants) { variant in
                    VariantSummaryRow(
                        variant: variant,
                        url: viewModel.uploadResult?.links[variant.kind],
                        copy: { url in
                            viewModel.copyLink(url)
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var latestLinkPreview: some View {
        if let result = viewModel.uploadResult, let url = latestPreviewURL(from: result) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(latestPreviewTitle, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    Spacer()
                    Button {
                        selectedSection = .links
                    } label: {
                        Label(L10n.text("button.view"), systemImage: "arrow.right")
                    }
                    .buttonStyle(.borderless)
                }

                Text(url.absoluteString)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let result = viewModel.uploadResult {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.text("links.latestUpload"))
                            .font(.headline)
                        Text("\(result.sourceName) · \(result.createdAt, format: Date.FormatStyle(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        viewModel.copyAllLinks()
                    } label: {
                        Label(L10n.text("button.copyAll"), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }

                ForEach(ImageVariantKind.allCases) { kind in
                    if let url = result.links[kind] {
                        LinkRow(kind: kind, url: url) {
                            viewModel.copyLink(url)
                        }
                    }
                }
            } else {
                EmptyStateView(
                    icon: "link.badge.plus",
                    title: L10n.text("empty.links.title"),
                    message: L10n.text("empty.links.message")
                )
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.uploadHistory.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: L10n.text("empty.history.title"),
                    message: L10n.text("empty.history.message")
                )
            } else {
                historyHeader

                if let item = viewModel.selectedHistoryItem {
                    HistoryPreviewCard(
                        item: item,
                        copyPrimary: {
                            if let url = item.primaryURL {
                                viewModel.copyLink(url)
                            }
                        },
                        copyMarkdown: {
                            viewModel.copyMarkdown(from: item)
                        },
                        copyAll: {
                            viewModel.copyAllLinks(from: item)
                        }
                    )
                }

                ForEach(viewModel.uploadHistory) { item in
                    HistoryItemRow(
                        item: item,
                        isSelected: viewModel.selectedHistoryItem?.id == item.id,
                        select: {
                            viewModel.selectHistoryItem(item)
                        },
                        copy: {
                            if let url = item.primaryURL {
                                viewModel.copyLink(url)
                            }
                        },
                        remove: {
                            viewModel.removeHistoryItem(item)
                        }
                    )
                }
            }
        }
    }

    private var historyHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text("history.title"))
                    .font(.headline)
                Text(L10n.format("history.count", viewModel.uploadHistory.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.clearHistory()
            } label: {
                Label(L10n.text("button.clear"), systemImage: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(L10n.format("app.version", AppVersion.current))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(viewModel.profile.provider.shortTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(L10n.text("button.settings")) {
                SettingsWindowPresenter.shared.openFromMenuBar(mode: .settings)
            }
            .buttonStyle(.borderless)
            Button(L10n.text("button.quit")) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
    }

    private var previewVariant: GeneratedImageVariant? {
        viewModel.generatedVariants.first { $0.kind == .thumbnail }
            ?? viewModel.generatedVariants.first { $0.kind == .compressed }
            ?? viewModel.generatedVariants.first
    }

    private var latestPreviewTitle: String {
        guard viewModel.profile.automaticallyCopyAfterUpload else {
            return L10n.text("links.uploaded")
        }

        return L10n.format("links.variantCopied", viewModel.profile.automaticCopyVariant.copiedTitle)
    }

    private func latestPreviewURL(from result: UploadResult) -> URL? {
        let preferredKind = viewModel.profile.automaticCopyVariant
        return result.links[preferredKind]
            ?? result.links[.compressed]
            ?? result.links[.original]
            ?? result.links[.thumbnail]
            ?? result.links[.webpReference]
    }
}
