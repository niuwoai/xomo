//
//  MenuBarUploadViewModel.swift
//  veilpic
//
//  Created by Codex on 2026/5/20.
//

import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

protocol ImageUploading {
    func upload(_ variants: [GeneratedImageVariant], profile: StorageProfile) async throws -> UploadResult
}

@MainActor
final class MenuBarUploadViewModel: ObservableObject {
    static let shared = MenuBarUploadViewModel()

    @Published var profile = StorageProfile() {
        didSet {
            profileStore.save(profile)
        }
    }
    @Published var uploadResult: UploadResult?
    @Published var statusMessage = "拖入图片，或点击剪贴板上传"
    @Published var isUploading = false
    @Published var isDropTargeted = false
    @Published var generatedVariants: [GeneratedImageVariant] = []
    @Published var phase: UploadPhase = .idle
    @Published var feedback: UserFeedback?
    @Published var suggestedSection: PanelSection?
    @Published var uploadHistory: [UploadHistoryItem]
    @Published var selectedHistoryItem: UploadHistoryItem?

    private let builder = ImageVariantBuilder()
    private let uploader: ImageUploading = ObjectStorageUploader()
    private let profileStore: StorageProfileStoring
    private let historyStore: UploadHistoryStoring

    init(
        profileStore: StorageProfileStoring? = nil,
        historyStore: UploadHistoryStoring? = nil
    ) {
        self.profileStore = profileStore ?? StorageProfileStore()
        self.historyStore = historyStore ?? UploadHistoryStore()
        uploadHistory = self.historyStore.load()
        profile = self.profileStore.load()
        selectedHistoryItem = uploadHistory.first
    }

    var configurationProgress: Double {
        profile.configurationProgress
    }

    var configurationSummary: String {
        let percent = Int((configurationProgress * 100).rounded())
        return "\(profile.provider.shortTitle) 配置完成度 \(percent)%"
    }

    var canUpload: Bool {
        !isUploading
    }

    var missingConfigurationText: String {
        profile.missingFields.joined(separator: "、")
    }

    func uploadFromClipboard() {
        guard canUpload else { return }
        phase = .reading

        guard let image = NSPasteboard.general.readImage() else {
            showFeedback(.warning, title: "剪贴板里没有图片", message: "请先复制截图或图片文件，再从托盘面板上传。")
            statusMessage = "剪贴板里没有可上传的图片"
            phase = .idle
            NSSound.beep()
            return
        }

        upload(image, sourceName: "剪贴板")
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard canUpload else { return false }
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) || $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            showFeedback(.warning, title: "不支持的文件", message: "请拖入图片文件，或先复制一张截图。")
            statusMessage = "只支持图片文件或图片数据"
            return false
        }

        phase = .reading
        statusMessage = "正在读取拖入的图片..."

        Task {
            if let image = await provider.loadImage() {
                upload(image, sourceName: "拖拽图片")
            } else {
                showFeedback(.error, title: "图片读取失败", message: "没有读到有效图片，请换一张图片再试。")
                statusMessage = "没有读到有效图片"
                phase = .failed
                NSSound.beep()
            }
        }

        return true
    }

    func copyLink(_ url: URL) {
        copy(url.absoluteString)
        showFeedback(.success, title: "链接已复制", message: url.absoluteString)
        statusMessage = "链接已复制"
    }

    func copyAllLinks() {
        guard let result = uploadResult else { return }
        let text = formattedLinks(result.links)

        copy(text)
        showFeedback(.success, title: "全部链接已复制", message: "已复制 \(result.links.count) 个链接。")
        statusMessage = "全部链接已复制"
    }

    func copyAllLinks(from item: UploadHistoryItem) {
        copy(formattedLinks(item.links))
        selectedHistoryItem = item
        showFeedback(.success, title: "历史链接已复制", message: "已复制 \(item.links.count) 个链接。")
        statusMessage = "历史链接已复制"
    }

    func copyMarkdown(from item: UploadHistoryItem) {
        guard let url = item.primaryURL else { return }
        copy("![\(item.sourceName)](\(url.absoluteString))")
        selectedHistoryItem = item
        showFeedback(.success, title: "Markdown 已复制", message: "可以直接粘贴到文档或 issue 里。")
        statusMessage = "Markdown 已复制"
    }

    func selectHistoryItem(_ item: UploadHistoryItem) {
        selectedHistoryItem = item
    }

    func removeHistoryItem(_ item: UploadHistoryItem) {
        uploadHistory = historyStore.remove(item, from: uploadHistory)
        selectedHistoryItem = uploadHistory.first
        showFeedback(.success, title: "历史已移除", message: "仅删除本地记录，不会删除云端图片。")
        statusMessage = "已删除一条历史"
    }

    func clearHistory() {
        historyStore.clear()
        uploadHistory = []
        selectedHistoryItem = nil
        showFeedback(.success, title: "历史已清空", message: "仅清空本地记录，不影响已经上传的图片。")
        statusMessage = "历史记录已清空"
    }

    func dismissFeedback() {
        feedback = nil
    }

    private func upload(_ image: NSImage, sourceName: String) {
        guard validateConfiguration() else { return }

        isUploading = true
        phase = .preparing
        feedback = UserFeedback(kind: .progress, title: "正在处理图片", message: "正在生成原图、压缩图和缩略图。")
        statusMessage = "正在生成多版本图片..."

        Task {
            let basename = "veilpic-\(Int(Date().timeIntervalSince1970))"
            let variants = builder.buildVariants(from: image, basename: basename)
            generatedVariants = variants

            guard !variants.isEmpty else {
                phase = .failed
                isUploading = false
                showFeedback(.error, title: "没有生成图片版本", message: "图片无法编码，请换一张图片再试。")
                statusMessage = "图片编码失败"
                NSSound.beep()
                return
            }

            do {
                phase = .uploading(current: 0, total: variants.count)
                statusMessage = "正在上传 \(variants.count) 个版本..."
                let result = try await uploader.upload(variants, profile: profile)
                phase = .copying
                uploadResult = result
                recordHistory(result: result, variants: variants)
                copyPrimaryLink(from: result)
                phase = .finished
                statusMessage = "已上传 \(result.links.count) 个版本"
                showFeedback(.success, title: "上传完成", message: "原图链接已复制到剪贴板。")
            } catch {
                phase = .failed
                statusMessage = "上传失败"
                showFeedback(.error, title: "上传失败", message: error.localizedDescription)
                NSSound.beep()
            }

            isUploading = false
        }
    }

    private func validateConfiguration() -> Bool {
        let missingFields = profile.missingFields
        guard missingFields.isEmpty else {
            phase = .failed
            showFeedback(.warning, title: "配置还没填完整", message: "请补充：\(missingFields.joined(separator: "、"))。")
            statusMessage = "请先补全存储配置"
            SettingsWindowPresenter.shared.openFromMenuBar(mode: .onboarding)
            NSSound.beep()
            return false
        }

        return true
    }

    private func copyPrimaryLink(from result: UploadResult) {
        guard let url = result.links[.original] else { return }
        copy(url.absoluteString)
    }

    private func recordHistory(result: UploadResult, variants: [GeneratedImageVariant]) {
        let thumbnailData = variants.first { $0.kind == .thumbnail }?.data ?? variants.first?.data
        let item = UploadHistoryItem(
            sourceName: result.sourceName,
            createdAt: result.createdAt,
            provider: profile.provider,
            bucket: profile.bucket,
            thumbnailData: thumbnailData,
            links: result.links
        )
        uploadHistory = historyStore.append(item, to: uploadHistory)
        selectedHistoryItem = item
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func showFeedback(_ kind: FeedbackKind, title: String, message: String) {
        feedback = UserFeedback(kind: kind, title: title, message: message)
    }

    private func formattedLinks(_ links: [ImageVariantKind: URL]) -> String {
        ImageVariantKind.allCases.compactMap { kind -> String? in
            guard let url = links[kind] else { return nil }
            return "\(kind.title): \(url.absoluteString)"
        }.joined(separator: "\n")
    }
}
