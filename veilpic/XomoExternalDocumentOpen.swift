//
//  XomoExternalDocumentOpen.swift
//  veilpic
//
//  Created by Codex on 2026/7/16.
//

import AppKit
import Combine
import Foundation

nonisolated enum XomoExternalDocumentKind: Equatable {
    case photoshop
    case image
}

nonisolated enum XomoExternalDocumentOpenPolicy {
    static let immediateSplashFileSize = 12 * 1_024 * 1_024
    static let delayedSplashNanoseconds: UInt64 = 180_000_000

    static func kind(for url: URL) -> XomoExternalDocumentKind? {
        switch url.pathExtension.lowercased() {
        case "psd":
            .photoshop
        case "png", "jpg", "jpeg", "tif", "tiff", "heic":
            .image
        default:
            nil
        }
    }

    static func supports(_ url: URL) -> Bool {
        kind(for: url) != nil
    }

    static func shouldShowImmediately(fileSize: Int?) -> Bool {
        guard let fileSize else { return false }
        return fileSize >= immediateSplashFileSize
    }
}

enum XomoDocumentLoadingStage: Equatable {
    case preparing
    case reading
    case decoding
    case decodingImage
    case rendering
    case finishing
}

struct XomoDocumentLoadingPresentation: Equatable {
    let fileName: String
    var stage: XomoDocumentLoadingStage

    var message: String {
        switch stage {
        case .preparing:
            L10n.format("startup.loading.preparing", fileName)
        case .reading:
            L10n.format("startup.loading.reading", fileName)
        case .decoding:
            L10n.text("startup.loading.decodingPSD")
        case .decodingImage:
            L10n.text("startup.loading.decodingImage")
        case .rendering:
            L10n.text("startup.loading.rendering")
        case .finishing:
            L10n.format("startup.loading.finishing", fileName)
        }
    }
}

@MainActor
final class XomoExternalDocumentOpenCoordinator: ObservableObject {
    static let shared = XomoExternalDocumentOpenCoordinator()

    @Published private(set) var presentation: XomoDocumentLoadingPresentation?

    private weak var viewModel: ImageEditorViewModel?
    private var pendingURL: URL?
    private var activeRequestID: UUID?
    private var activeFileName = ""
    private var activeStage: XomoDocumentLoadingStage = .preparing
    private var loadTask: Task<Void, Never>?
    private var delayedPresentationTask: Task<Void, Never>?

    func register(_ viewModel: ImageEditorViewModel) {
        self.viewModel = viewModel
        startPendingOpenIfPossible()
    }

    func unregister(_ viewModel: ImageEditorViewModel) {
        guard self.viewModel === viewModel else { return }
        self.viewModel = nil
    }

    func open(_ urls: [URL]) {
        guard let url = urls.first(where: XomoExternalDocumentOpenPolicy.supports) else { return }
        open(url)
    }

    func open(_ url: URL) {
        guard XomoExternalDocumentOpenPolicy.supports(url) else { return }

        loadTask?.cancel()
        loadTask = nil
        delayedPresentationTask?.cancel()
        delayedPresentationTask = nil
        pendingURL = url
        activeRequestID = nil
        activeFileName = url.lastPathComponent
        activeStage = .preparing

        let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        if XomoExternalDocumentOpenPolicy.shouldShowImmediately(fileSize: fileSize) {
            presentation = XomoDocumentLoadingPresentation(
                fileName: activeFileName,
                stage: activeStage
            )
        } else {
            presentation = nil
        }

        startPendingOpenIfPossible()
    }

    private func startPendingOpenIfPossible() {
        guard loadTask == nil,
              let viewModel,
              let url = pendingURL
        else { return }

        pendingURL = nil
        let requestID = UUID()
        activeRequestID = requestID
        scheduleDelayedPresentation(requestID: requestID)

        loadTask = Task { [weak self, weak viewModel] in
            guard let self, let viewModel else { return }
            await performOpen(url: url, requestID: requestID, viewModel: viewModel)
        }
    }

    private func scheduleDelayedPresentation(requestID: UUID) {
        guard presentation == nil else { return }
        delayedPresentationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: XomoExternalDocumentOpenPolicy.delayedSplashNanoseconds)
            guard !Task.isCancelled,
                  let self,
                  self.activeRequestID == requestID
            else { return }
            self.presentation = XomoDocumentLoadingPresentation(
                fileName: self.activeFileName,
                stage: self.activeStage
            )
        }
    }

    private func performOpen(
        url: URL,
        requestID: UUID,
        viewModel: ImageEditorViewModel
    ) async {
        guard let documentKind = XomoExternalDocumentOpenPolicy.kind(for: url) else {
            finish(requestID: requestID)
            return
        }
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            updateStage(.reading, requestID: requestID)
            let data = try await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: url, options: .mappedIfSafe)
            }.value
            try Task.checkCancellation()

            if documentKind == .image {
                updateStage(.decodingImage, requestID: requestID)
                guard let image = NSImage(data: data) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                try Task.checkCancellation()
                updateStage(.finishing, requestID: requestID)
                await Task.yield()
                guard activeRequestID == requestID else { return }
                viewModel.loadExternalImageDocument(
                    ImageEditorDocument(sourceName: url.lastPathComponent, image: image)
                )
                activateOpenedDocumentWindow()
                finish(requestID: requestID)
                return
            }

            updateStage(.decoding, requestID: requestID)
            let document: ImageEditorDocument
            let openedFlattened: Bool
            var compatibilityReport = try? ImageEditorPSDCodec.compatibilityReport(data)
            do {
                document = try await ImageEditorPSDCodec.decodeAsync(
                    data,
                    sourceName: url.lastPathComponent,
                    onWillMaterialize: { [weak self] in
                        self?.updateStage(.rendering, requestID: requestID)
                    }
                )
                openedFlattened = false
            } catch {
                try Task.checkCancellation()
                guard let flattened = NSImage(contentsOf: url) else { throw error }
                document = ImageEditorDocument(
                    sourceName: url.lastPathComponent,
                    image: flattened
                )
                openedFlattened = true
                compatibilityReport = compatibilityReport?.addingFlattenedFallback()
            }

            try Task.checkCancellation()
            updateStage(.finishing, requestID: requestID)
            await Task.yield()
            guard activeRequestID == requestID else { return }
            viewModel.loadExternalPSDDocument(
                document,
                openedFlattened: openedFlattened,
                compatibilityReport: compatibilityReport
            )
            activateOpenedDocumentWindow()
            finish(requestID: requestID)
        } catch is CancellationError {
            finish(requestID: requestID)
        } catch {
            viewModel.statusText = L10n.format(
                "imageEditor.status.projectOpenFailedWithReason",
                error.localizedDescription
            )
            finish(requestID: requestID)
        }
    }

    private func activateOpenedDocumentWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.keyWindow?.makeKeyAndOrderFront(nil)
    }

    private func updateStage(_ stage: XomoDocumentLoadingStage, requestID: UUID) {
        guard activeRequestID == requestID else { return }
        activeStage = stage
        guard presentation != nil else { return }
        presentation = XomoDocumentLoadingPresentation(fileName: activeFileName, stage: stage)
    }

    private func finish(requestID: UUID) {
        guard activeRequestID == requestID else { return }
        delayedPresentationTask?.cancel()
        delayedPresentationTask = nil
        presentation = nil
        activeRequestID = nil
        loadTask = nil
        startPendingOpenIfPossible()
    }
}
