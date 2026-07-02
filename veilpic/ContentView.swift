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
            .frame(width: 480, height: 600)
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
    @StateObject private var screenshotShortcuts = ScreenshotShortcutSettings.shared
    @ObservedObject private var dockVisibility = DockVisibilitySettings.shared
    let mode: SettingsPresentationMode

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsHeader

            Divider()
                .overlay(AppTheme.hairline)

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
                    screenshotBehaviorSection
                    screenshotShortcutsSection
                    launchAtLoginSection
                    dockVisibilitySection
                    firstRunNote
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
                .overlay(AppTheme.hairline)

            settingsFooter
        }
        .frame(width: 560, height: 620)
        .themedWindowBackground()
    }

    private var settingsHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accent.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AppTheme.accent.opacity(0.32), radius: 7, x: 0, y: 3)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
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
        .themedCard()
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
        .themedCard()
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
        .themedCard()
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
        .themedCard()
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
        .themedCard()
    }

    private var screenshotBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("settings.screenshotBehavior"))
                .font(.headline)

            Toggle(isOn: $viewModel.profile.automaticallyCopyScreenshotToClipboard) {
                Label(L10n.text("settings.screenshotAutoCopy.title"), systemImage: "doc.on.clipboard")
                    .font(.caption.weight(.semibold))
            }

            Text(L10n.text("settings.screenshotAutoCopy.note"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .themedCard()
    }

    private var screenshotShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.text("settings.screenshotShortcuts"), systemImage: "keyboard")
                    .font(.headline)

                Spacer()

                Button {
                    screenshotShortcuts.resetToDefaults()
                } label: {
                    Label(L10n.text("settings.shortcut.reset"), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            VStack(spacing: 8) {
                ScreenshotShortcutEditorRow(
                    title: L10n.text("settings.shortcut.fullscreen"),
                    shortcut: $screenshotShortcuts.fullScreenShortcut
                )
                ScreenshotShortcutEditorRow(
                    title: L10n.text("settings.shortcut.region"),
                    shortcut: $screenshotShortcuts.regionShortcut
                )
            }

            Text(L10n.text("settings.screenshotShortcuts.note"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .themedCard()
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
        .themedCard()
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

private struct ScreenshotShortcutEditorRow: View {
    let title: String
    @Binding var shortcut: ScreenshotKeyboardShortcut

    private let modifierOptions: [(NSEvent.ModifierFlags, String)] = [
        (.control, "⌃"),
        (.option, "⌥"),
        (.shift, "⇧"),
        (.command, "⌘")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text(shortcut.displayText)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack(spacing: 8) {
                ForEach(modifierOptions, id: \.0.rawValue) { option in
                    Toggle(option.1, isOn: modifierBinding(option.0))
                        .toggleStyle(.button)
                        .controlSize(.small)
                }

                Spacer()

                Picker(L10n.text("settings.shortcut.key"), selection: keyBinding) {
                    ForEach(ScreenshotShortcutKey.allCases) { key in
                        Text(key.rawValue)
                            .tag(key)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 72)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.54))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AppTheme.hairline, lineWidth: 1)
        }
    }

    private var keyBinding: Binding<ScreenshotShortcutKey> {
        Binding(
            get: { shortcut.key },
            set: { shortcut = ScreenshotKeyboardShortcut(key: $0, modifiers: shortcut.normalizedModifiers) }
        )
    }

    private func modifierBinding(_ modifier: NSEvent.ModifierFlags) -> Binding<Bool> {
        Binding(
            get: { shortcut.normalizedModifiers.contains(modifier) },
            set: { isEnabled in
                var next = shortcut.normalizedModifiers
                if isEnabled {
                    next.insert(modifier)
                } else {
                    let activeCount = modifierOptions.filter { next.contains($0.0) }.count
                    guard activeCount > 1 else { return }
                    next.remove(modifier)
                }
                shortcut = ScreenshotKeyboardShortcut(key: shortcut.key, modifiers: next)
            }
        )
    }
}

struct MenuBarPanelView: View {
    @ObservedObject var viewModel: MenuBarUploadViewModel
    @State private var selectedSection: PanelSection = .workbench

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                header
                SectionPillNav(selection: $selectedSection)
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
        .themedWindowBackground()
        .animation(.snappy(duration: 0.2), value: viewModel.feedback)
        .onChange(of: viewModel.suggestedSection) { _, section in
            guard let section else { return }
            selectedSection = section
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accent.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AppTheme.accent.opacity(0.32), radius: 6, x: 0, y: 3)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
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
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 30, height: 30)
                        .background(AppTheme.controlFill)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(AppTheme.hairline, lineWidth: 1)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.text("help.openSettings"))
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if viewModel.isUploading || viewModel.phase != .idle {
                    UploadProgressView(phase: viewModel.phase, stats: viewModel.uploadStats)
                }

                switch selectedSection {
                case .workbench:
                    workbenchSection
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

    private var workbenchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !viewModel.profile.isReadyForUpload {
                configurationPrompt
            }
            intakeTiles
            workspacePreview
            postProcessTemplates
            workspaceActions
            uploadQuickStats
            variantPreview
            latestLinkPreview
        }
    }

    private var heroDropZone: some View {
        HeroDropZone(isTargeted: viewModel.isDropTargeted) {
            viewModel.chooseImageFiles()
        }
        .onDrop(
            of: [UTType.image.identifier, UTType.fileURL.identifier],
            isTargeted: $viewModel.isDropTargeted,
            perform: viewModel.handleDrop
        )
    }

    private var intakeTiles: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                CompactWorkbenchButton(
                    icon: "selection.pin.in.out",
                    title: L10n.text("workbench.intake.region"),
                    subtitle: L10n.text("workbench.intake.region.subtitle")
                ) {
                    viewModel.captureRegionToWorkspace()
                }

                CompactWorkbenchButton(
                    icon: "rectangle.on.rectangle",
                    title: L10n.text("workbench.intake.fullscreen"),
                    subtitle: L10n.text("workbench.intake.fullscreen.subtitle")
                ) {
                    viewModel.captureFullScreenToWorkspace()
                }
            }

            HStack(spacing: 10) {
                CompactWorkbenchButton(
                    icon: "doc.on.clipboard",
                    title: L10n.text("tile.clipboard.title"),
                    subtitle: L10n.text("tile.clipboard.subtitle")
                ) {
                    viewModel.uploadFromClipboard()
                }

                CompactWorkbenchButton(
                    icon: "photo.on.rectangle",
                    title: L10n.text("tile.images.title"),
                    subtitle: L10n.text("tile.images.subtitle")
                ) {
                    viewModel.chooseImageFiles()
                }
            }
        }
    }

    private var legacyUploadTiles: some View {
        HStack(spacing: 12) {
            UploadActionTile(
                icon: "doc.on.clipboard",
                title: L10n.text("tile.clipboard.title"),
                subtitle: L10n.text("tile.clipboard.subtitle"),
                style: .filledAccent
            ) {
                viewModel.uploadFromClipboard()
            }

            UploadActionTile(
                icon: "photo.on.rectangle",
                title: L10n.text("tile.images.title"),
                subtitle: L10n.text("tile.images.subtitle"),
                style: .sandOutline
            ) {
                viewModel.chooseImageFiles()
            }

            UploadActionTile(
                icon: "folder.badge.plus",
                title: L10n.text("tile.folder.title"),
                subtitle: L10n.text("tile.folder.subtitle"),
                style: .accentOutline
            ) {
                viewModel.chooseImageDirectory()
            }
        }
    }

    @ViewBuilder
    private var workspacePreview: some View {
        if let item = viewModel.workspaceItem {
            WorkbenchPreviewCard(
                item: item,
                template: viewModel.postProcessRecipe.template,
                imageData: viewModel.processedPreviewData
            )
        } else {
            heroDropZone
        }
    }

    private var postProcessTemplates: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("post.templates.title"))
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(PostProcessTemplate.allCases) { template in
                    TemplatePillButton(
                        template: template,
                        isSelected: viewModel.postProcessRecipe.template == template
                    ) {
                        viewModel.selectPostProcessTemplate(template)
                    }
                }
            }
        }
    }

    private var workspaceActions: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            Button {
                viewModel.annotateWorkspaceImage()
            } label: {
                Label(L10n.text("workbench.action.annotate"), systemImage: "pencil.and.outline")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.workspaceItem == nil)

            Button {
                viewModel.saveProcessedImage()
            } label: {
                Label(L10n.text("workbench.action.saveImage"), systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.workspaceItem == nil)

            Button {
                viewModel.uploadWorkspaceImage()
            } label: {
                Label(L10n.text("workbench.action.upload"), systemImage: "arrow.up.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.workspaceItem == nil || viewModel.isUploading)

            Button {
                viewModel.copyProcessedImage()
            } label: {
                Label(L10n.text("workbench.action.copyImage"), systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.workspaceItem == nil)
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
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.2))
        }
    }

    private var uploadQuickStats: some View {
        HStack(spacing: 10) {
            MetricPill(title: L10n.text("metric.provider"), value: viewModel.profile.provider.shortTitle, icon: viewModel.profile.provider.symbolName, iconColor: AppTheme.accent)
            MetricPill(title: L10n.text("metric.path"), value: viewModel.profile.objectPrefix.isEmpty ? L10n.text("metric.dateFolder") : viewModel.profile.objectPrefix, icon: "folder", iconColor: AppTheme.sandIcon)
            MetricPill(title: L10n.text("metric.config"), value: "\(Int((viewModel.configurationProgress * 100).rounded()))%", icon: "checkmark.seal", iconColor: Color(red: 0.11, green: 0.62, blue: 0.46))
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
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.green.opacity(0.18), lineWidth: 1)
            }
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
