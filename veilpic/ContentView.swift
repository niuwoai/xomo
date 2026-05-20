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

struct StorageSettingsView: View {
    @ObservedObject var viewModel: MenuBarUploadViewModel
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
                Text(mode == .onboarding ? "开始使用轻图" : "轻图设置")
                    .font(.title2.weight(.semibold))
                Text("配置 OSS / S3 等对象存储；之后从菜单栏图标快速上传图片。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(22)
    }

    private var onboardingSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("三步完成初始化")
                .font(.headline)

            HStack(alignment: .top, spacing: 10) {
                OnboardingStepView(
                    number: 1,
                    title: "准备存储",
                    message: "选择 OSS / S3 或兼容服务，准备 bucket、endpoint 和访问密钥。",
                    isDone: true,
                    icon: "externaldrive.connected.to.line.below"
                )

                OnboardingStepView(
                    number: 2,
                    title: "填写配置",
                    message: viewModel.profile.missingFields.isEmpty ? "连接信息已完整，可以开始上传。" : "补齐必填项：\(viewModel.missingConfigurationText)。",
                    isDone: viewModel.profile.isReadyForUpload,
                    icon: "key.horizontal"
                )

                OnboardingStepView(
                    number: 3,
                    title: "回到菜单栏",
                    message: "之后点击菜单栏里的轻图图标，拖图或读取剪贴板即可上传。",
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
                Label("配置已完整，可以回到菜单栏上传图片。", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Label("待补充：\(viewModel.missingConfigurationText)", systemImage: "exclamationmark.triangle.fill")
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
            Text("存储后端")
                .font(.headline)

            Picker("存储后端", selection: $viewModel.profile.provider) {
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
                Text("凭据类型")
                    .font(.headline)

                Picker("凭据类型", selection: $viewModel.profile.credentialMode) {
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
            Text("连接信息")
                .font(.headline)

            ConfigField(title: "Bucket", icon: "shippingbox", text: $viewModel.profile.bucket)
            ConfigField(title: "Region", icon: "map", text: $viewModel.profile.region, prompt: viewModel.profile.provider.regionPlaceholder, isRequired: false)
            ConfigField(title: "Endpoint / API 域名", icon: "network", text: $viewModel.profile.endpoint, prompt: viewModel.profile.provider.endpointPlaceholder)
            ConfigField(title: "CDN 域名", icon: "globe", text: $viewModel.profile.cdnDomain, prompt: "https://img.example.com", isRequired: viewModel.profile.provider == .qiniuKodo)
            ConfigField(title: "对象前缀", icon: "folder", text: $viewModel.profile.objectPrefix, prompt: "veilpic", isRequired: false)
            ConfigField(title: viewModel.profile.provider.accessKeyLabel, icon: "key", text: $viewModel.profile.accessKeyId)
            SecretConfigField(title: viewModel.profile.provider.secretKeyLabel, icon: "lock", text: $viewModel.profile.accessKeySecret)

            if viewModel.profile.provider.supportsTemporaryCredentials, viewModel.profile.credentialMode == .temporary {
                SecretConfigField(title: "Session Token", icon: "ticket", text: $viewModel.profile.sessionToken)
            }
        }
    }

    private var firstRunNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("使用方式", systemImage: "menubar.rectangle")
                .font(.headline)
            Text("配置完成后，轻图会留在菜单栏。点击菜单栏图标即可拖拽图片、读取剪贴板、复制上传链接；设置也可以随时从托盘面板打开。")
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
            Text("版本 \(AppVersion.current)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("完成") {
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
        VStack(alignment: .leading, spacing: 12) {
            header
            sectionPicker

            if let feedback = viewModel.feedback {
                FeedbackBanner(feedback: feedback, dismiss: viewModel.dismissFeedback)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            content
            footer
        }
        .padding(16)
        .animation(.snappy(duration: 0.18), value: viewModel.feedback)
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
                Text("轻图")
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
                    SettingsWindowPresenter.shared.open(mode: .settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("打开设置")
            }
        }
    }

    private var sectionPicker: some View {
        Picker("面板", selection: $selectedSection) {
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
                    UploadProgressView(phase: viewModel.phase)
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
                Text("先配置对象存储")
                    .font(.caption.weight(.semibold))
                Text("轻图需要 OSS / S3 等存储信息，配置后就能从菜单栏快速上传。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                SettingsWindowPresenter.shared.open(mode: .onboarding)
            } label: {
                Label("设置", systemImage: "arrow.up.right.square")
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

            Text(viewModel.isDropTargeted ? "松开即可上传" : "拖拽图片到这里")
                .font(.headline)

            Text("生成原图、压缩图、缩略图和 WebP；上传成功后自动复制原图链接。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Button {
                viewModel.uploadFromClipboard()
            } label: {
                Label(viewModel.isUploading ? "正在上传" : "读取剪贴板并上传", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canUpload)
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
            MetricPill(title: "后端", value: viewModel.profile.provider.shortTitle, icon: viewModel.profile.provider.symbolName)
            MetricPill(title: "路径", value: viewModel.profile.objectPrefix.isEmpty ? "日期目录" : viewModel.profile.objectPrefix, icon: "folder")
            MetricPill(title: "配置", value: "\(Int((viewModel.configurationProgress * 100).rounded()))%", icon: "checkmark.seal")
        }
    }

    @ViewBuilder
    private var currentImagePreview: some View {
        if let variant = previewVariant {
            ImagePreviewCard(
                title: "图片预览",
                subtitle: "本次上传将优先使用缩略图做历史封面",
                imageData: variant.data,
                footer: variant.byteCountText
            )
        }
    }

    @ViewBuilder
    private var variantPreview: some View {
        if !viewModel.generatedVariants.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("本次生成")
                    .font(.headline)
                ForEach(viewModel.generatedVariants) { variant in
                    VariantSummaryRow(variant: variant)
                }
            }
        }
    }

    @ViewBuilder
    private var latestLinkPreview: some View {
        if let result = viewModel.uploadResult, let url = result.links[.original] {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("原图链接已复制", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    Spacer()
                    Button {
                        selectedSection = .links
                    } label: {
                        Label("查看", systemImage: "arrow.right")
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
                        Text("最新上传")
                            .font(.headline)
                        Text("\(result.sourceName) · \(result.createdAt, format: Date.FormatStyle(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        viewModel.copyAllLinks()
                    } label: {
                        Label("全部复制", systemImage: "doc.on.doc")
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
                    title: "还没有上传结果",
                    message: "上传完成后，这里会列出原图、压缩图、缩略图和 WebP 链接。"
                )
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.uploadHistory.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "还没有上传历史",
                    message: "之后上传的图片会在本机保存预览、链接和时间，方便随时找回。"
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
                Text("上传历史")
                    .font(.headline)
                Text("本地保存最近 \(viewModel.uploadHistory.count) 条记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.clearHistory()
            } label: {
                Label("清空", systemImage: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("版本 \(AppVersion.current)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(viewModel.profile.provider.shortTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("设置") {
                SettingsWindowPresenter.shared.open(mode: .settings)
            }
            .buttonStyle(.borderless)
            Button("退出") {
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
}
