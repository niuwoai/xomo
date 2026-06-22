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
    @Published var statusMessage = L10n.text("status.idle")
    @Published var isUploading = false
    @Published var isDropTargeted = false
    @Published var generatedVariants: [GeneratedImageVariant] = []
    @Published var phase: UploadPhase = .idle
    @Published var uploadStats = UploadDashboardState.idle
    @Published var feedback: UserFeedback?
    @Published var suggestedSection: PanelSection?
    @Published var uploadHistory: [UploadHistoryItem]
    @Published var selectedHistoryItem: UploadHistoryItem?

    private let builder = ImageVariantBuilder()
    private let uploader: ImageUploading = ObjectStorageUploader()
    private let profileStore: StorageProfileStoring
    private let historyStore: UploadHistoryStoring
    private var pendingUploadItems: [LocalImageUploadItem] = []
    private let maxConcurrentUploads = 3

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
        return L10n.format("settings.configSummary", profile.provider.shortTitle, percent)
    }

    var canUpload: Bool {
        true
    }

    var missingConfigurationText: String {
        profile.missingFields.joined(separator: L10n.text("punctuation.listSeparator"))
    }

    func uploadFromClipboard() {
        phase = .reading

        guard let image = NSPasteboard.general.readImage() else {
            showFeedback(.warning, title: L10n.text("feedback.clipboard.empty.title"), message: L10n.text("feedback.clipboard.empty.message"))
            statusMessage = L10n.text("status.clipboard.empty")
            phase = .idle
            NSSound.beep()
            return
        }

        upload(image, sourceName: L10n.text("source.clipboard"))
    }

    func chooseImageFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = L10n.text("button.chooseImages")

        guard panel.runModal() == .OK else { return }
        uploadImageFiles(panel.urls)
    }

    func chooseImageDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = L10n.text("button.chooseFolder")

        guard panel.runModal() == .OK, let directory = panel.url else { return }
        uploadImageFiles(imageFileURLs(in: directory))
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) || $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            showFeedback(.warning, title: L10n.text("feedback.unsupported.title"), message: L10n.text("feedback.unsupported.message"))
            statusMessage = L10n.text("status.unsupported")
            return false
        }

        phase = .reading
        statusMessage = L10n.text("status.readingDrop")

        Task {
            if let image = await provider.loadImage() {
                upload(image, sourceName: L10n.text("source.drop"))
            } else {
                showFeedback(.error, title: L10n.text("feedback.read.failed.title"), message: L10n.text("feedback.read.failed.message"))
                statusMessage = L10n.text("status.read.failed")
                phase = .failed
                NSSound.beep()
            }
        }

        return true
    }

    func copyLink(_ url: URL) {
        copy(url.absoluteString)
        showFeedback(.success, title: L10n.text("feedback.linkCopied.title"), message: url.absoluteString)
        statusMessage = L10n.text("status.linkCopied")
    }

    func copyAllLinks() {
        guard let result = uploadResult else { return }
        let text = formattedLinks(result.links)

        copy(text)
        showFeedback(.success, title: L10n.text("feedback.allLinksCopied.title"), message: L10n.format("feedback.linksCopied.message", result.links.count))
        statusMessage = L10n.text("status.allLinksCopied")
    }

    func copyAllLinks(from item: UploadHistoryItem) {
        copy(formattedLinks(item.links))
        selectedHistoryItem = item
        showFeedback(.success, title: L10n.text("feedback.historyLinksCopied.title"), message: L10n.format("feedback.linksCopied.message", item.links.count))
        statusMessage = L10n.text("status.historyLinksCopied")
    }

    func copyMarkdown(from item: UploadHistoryItem) {
        guard let url = item.primaryURL else { return }
        copy("![\(item.sourceName)](\(url.absoluteString))")
        selectedHistoryItem = item
        showFeedback(.success, title: L10n.text("feedback.markdownCopied.title"), message: L10n.text("feedback.markdownCopied.message"))
        statusMessage = L10n.text("status.markdownCopied")
    }

    func selectHistoryItem(_ item: UploadHistoryItem) {
        selectedHistoryItem = item
    }

    func removeHistoryItem(_ item: UploadHistoryItem) {
        uploadHistory = historyStore.remove(item, from: uploadHistory)
        selectedHistoryItem = uploadHistory.first
        showFeedback(.success, title: L10n.text("feedback.historyRemoved.title"), message: L10n.text("feedback.historyRemoved.message"))
        statusMessage = L10n.text("status.historyRemoved")
    }

    func clearHistory() {
        historyStore.clear()
        uploadHistory = []
        selectedHistoryItem = nil
        showFeedback(.success, title: L10n.text("feedback.historyCleared.title"), message: L10n.text("feedback.historyCleared.message"))
        statusMessage = L10n.text("status.historyCleared")
    }

    func dismissFeedback() {
        feedback = nil
    }

    private func upload(_ image: NSImage, sourceName: String) {
        let item = LocalImageUploadItem(image: image, url: nil, sourceName: sourceName, basename: uniqueBasename(from: sourceName))
        uploadItems([item])
    }

    private func uploadImageFiles(_ urls: [URL]) {
        guard validateConfiguration() else { return }

        let items = urls
            .filter(isImageFile)
            .map { LocalImageUploadItem(image: nil, url: $0, sourceName: $0.lastPathComponent, basename: uniqueBasename(from: $0.deletingPathExtension().lastPathComponent)) }

        guard !items.isEmpty else {
            phase = .failed
            showFeedback(.warning, title: L10n.text("feedback.folder.empty.title"), message: L10n.text("feedback.folder.empty.message"))
            statusMessage = L10n.text("status.noImagesSelected")
            NSSound.beep()
            return
        }

        uploadItems(items)
    }

    private func uploadItems(_ items: [LocalImageUploadItem]) {
        guard validateConfiguration() else { return }
        guard !items.isEmpty else { return }

        if isUploading {
            pendingUploadItems.append(contentsOf: items)
            showFeedback(.progress, title: L10n.text("feedback.queue.added.title"), message: L10n.format("feedback.queue.added.message", items.count, pendingUploadItems.count))
            statusMessage = L10n.format("status.queue.added", pendingUploadItems.count)
            return
        }

        performUploadItems(items)
    }

    private func performUploadItems(_ items: [LocalImageUploadItem]) {
        isUploading = true
        phase = .reading
        uploadStats = UploadDashboardState(
            totalTasks: items.count,
            completedTasks: 0,
            failedTasks: 0,
            activeTasks: min(items.count, maxConcurrentUploads),
            queuedTasks: max(items.count - maxConcurrentUploads, 0),
            uploadedBytes: 0,
            startedAt: Date()
        )
        feedback = UserFeedback(kind: .progress, title: L10n.text("feedback.processing.title"), message: L10n.format("feedback.batch.processing.message", items.count))
        statusMessage = L10n.format("status.batch.uploadingSummary", 0, items.count, uploadStats.speedText)

        Task {
            var uploadedResults: [UploadResult] = []
            var failedCount = 0
            var failureMessages: [String] = []
            var preparedItems: [PreparedUploadItem] = []

            for item in items {
                if let prepared = prepareUploadItem(item) {
                    preparedItems.append(prepared)
                } else {
                    failedCount += 1
                    failureMessages.append(L10n.format("feedback.batch.readFailed.reason", item.sourceName))
                }
            }

            if preparedItems.isEmpty {
                finishBatchUpload(uploadedResults: [], failedCount: failedCount, failureMessages: failureMessages)
                return
            }

            phase = .uploading(current: 0, total: items.count)
            await withTaskGroup(of: UploadItemOutcome.self) { group in
                var nextIndex = 0
                let initialCount = min(maxConcurrentUploads, preparedItems.count)

                for _ in 0..<initialCount {
                    let item = preparedItems[nextIndex]
                    nextIndex += 1
                    group.addTask {
                        await Self.uploadPreparedItem(item, profile: item.profile)
                    }
                }

                for await outcome in group {
                    switch outcome {
                    case .success(let result, let variants, let byteCount):
                        uploadResult = result
                        recordHistory(result: result, variants: variants)
                        uploadedResults.append(result)
                        uploadStats.completedTasks += 1
                        uploadStats.uploadedBytes += byteCount
                    case .failure(let sourceName, let message):
                        failedCount += 1
                        failureMessages.append(L10n.format("feedback.batch.uploadFailed.reason", sourceName, message))
                        uploadStats.failedTasks += 1
                    }

                    let finishedTasks = uploadStats.completedTasks + uploadStats.failedTasks
                    phase = .uploading(current: finishedTasks, total: items.count)
                    uploadStats.activeTasks = max(min(preparedItems.count - finishedTasks, maxConcurrentUploads), 0)
                    uploadStats.queuedTasks = max(preparedItems.count - finishedTasks - uploadStats.activeTasks, 0)
                    statusMessage = L10n.format("status.batch.uploadingSummary", finishedTasks, items.count, uploadStats.speedText)

                    if nextIndex < preparedItems.count {
                        let item = preparedItems[nextIndex]
                        nextIndex += 1
                        group.addTask {
                            await Self.uploadPreparedItem(item, profile: item.profile)
                        }
                    }
                }
            }

            finishBatchUpload(uploadedResults: uploadedResults, failedCount: failedCount, failureMessages: failureMessages)
        }
    }

    private func finishBatchUpload(uploadedResults: [UploadResult], failedCount: Int, failureMessages: [String]) {
        guard !uploadedResults.isEmpty else {
            phase = .failed
            isUploading = false
            statusMessage = L10n.text("status.upload.failed")
            showFeedback(.error, title: L10n.text("feedback.upload.failed.title"), message: batchFailureMessage(failedCount: failedCount, failureMessages: failureMessages))
            NSSound.beep()
            startNextQueuedUploadIfNeeded()
            return
        }

        phase = .copying
        let copiedKind = copyAutomaticLinks(from: uploadedResults)
        phase = .finished
        isUploading = false
        statusMessage = L10n.format("status.batch.done", uploadedResults.count)
        if failedCount > 0 {
            showFeedback(.warning, title: L10n.text("feedback.batch.partial.title"), message: batchFailureMessage(failedCount: failedCount, failureMessages: failureMessages))
        } else {
            showFeedback(.success, title: L10n.text("feedback.upload.done.title"), message: uploadDoneMessage(uploadedCount: uploadedResults.count, failedCount: failedCount, copiedKind: copiedKind))
        }

        startNextQueuedUploadIfNeeded()
    }

    private func startNextQueuedUploadIfNeeded() {
        guard !pendingUploadItems.isEmpty else { return }
        let nextItems = pendingUploadItems
        pendingUploadItems = []
        performUploadItems(nextItems)
    }

    private func prepareUploadItem(_ item: LocalImageUploadItem) -> PreparedUploadItem? {
        guard let image = item.image ?? item.url.flatMap({ NSImage(contentsOf: $0) }) else {
            return nil
        }

        let variants = builder.buildVariants(from: image, basename: item.basename)
        generatedVariants = variants
        guard !variants.isEmpty else {
            return nil
        }

        let byteCount = variants.reduce(0) { $0 + $1.data.count }
        return PreparedUploadItem(sourceName: item.sourceName, variants: variants, profile: profile, byteCount: byteCount)
    }

    nonisolated private static func uploadPreparedItem(_ item: PreparedUploadItem, profile: StorageProfile) async -> UploadItemOutcome {
        do {
            let uploaded = try await ObjectStorageUploader().upload(item.variants, profile: profile)
            let result = UploadResult(sourceName: item.sourceName, createdAt: uploaded.createdAt, links: uploaded.links)
            return .success(result: result, variants: item.variants, byteCount: item.byteCount)
        } catch {
            return .failure(sourceName: item.sourceName, message: error.localizedDescription)
        }
    }

    private func validateConfiguration() -> Bool {
        let missingFields = profile.missingFields
        guard missingFields.isEmpty else {
            phase = .failed
            showFeedback(.warning, title: L10n.text("feedback.configIncomplete.title"), message: L10n.format("feedback.configIncomplete.message", missingFields.joined(separator: L10n.text("punctuation.listSeparator"))))
            statusMessage = L10n.text("status.configIncomplete")
            SettingsWindowPresenter.shared.openFromMenuBar(mode: .onboarding)
            NSSound.beep()
            return false
        }

        return true
    }

    private func copyAutomaticLinks(from results: [UploadResult]) -> ImageVariantKind? {
        guard profile.automaticallyCopyAfterUpload else { return nil }
        let preferredKind = profile.automaticCopyVariant
        let lines = results.compactMap { result -> String? in
            guard let url = urlToCopy(from: result, preferredKind: preferredKind) else {
                return nil
            }

            return L10n.format("links.formattedLine", result.sourceName, url.absoluteString)
        }

        guard !lines.isEmpty else { return nil }
        copy(lines.joined(separator: "\n"))
        return preferredKind
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
            return L10n.format("links.formattedLine", kind.title, url.absoluteString)
        }.joined(separator: "\n")
    }

    private func urlToCopy(from result: UploadResult, preferredKind: ImageVariantKind) -> URL? {
        result.links[preferredKind]
            ?? result.links[.compressed]
            ?? result.links[.original]
            ?? result.links[.thumbnail]
            ?? result.links[.webpReference]
    }

    private func uploadDoneMessage(uploadedCount: Int, failedCount: Int, copiedKind: ImageVariantKind?) -> String {
        guard let copiedKind else {
            return L10n.format("feedback.batch.doneNoCopy.message", uploadedCount, failedCount)
        }

        return L10n.format("feedback.batch.doneWithCopy.message", uploadedCount, failedCount, copiedKind.copiedTitle)
    }

    private func batchFailureMessage(failedCount: Int, failureMessages: [String]) -> String {
        let reason = failureMessages.first ?? L10n.text("feedback.batch.unknown.reason")
        return L10n.format("feedback.batch.failedWithReason.message", failedCount, reason)
    }

    private func imageFileURLs(in directory: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? URL }
            .filter(isImageFile)
    }

    private func isImageFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    private func uniqueBasename(from sourceName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = sourceName
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
            .split(separator: "-")
            .joined(separator: "-")
        let prefix = sanitized.isEmpty ? "veilpic" : sanitized
        return "\(prefix)-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(8).lowercased())"
    }
}

private struct LocalImageUploadItem {
    let image: NSImage?
    let url: URL?
    let sourceName: String
    let basename: String
}

private struct PreparedUploadItem: Sendable {
    let sourceName: String
    let variants: [GeneratedImageVariant]
    let profile: StorageProfile
    let byteCount: Int
}

private enum UploadItemOutcome: Sendable {
    case success(result: UploadResult, variants: [GeneratedImageVariant], byteCount: Int)
    case failure(sourceName: String, message: String)
}
