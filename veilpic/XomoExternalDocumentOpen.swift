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
    case editableSVG
}

nonisolated enum XomoExternalDocumentOpenError: LocalizedError {
    case unsupportedEditableSVG

    var errorDescription: String? {
        switch self {
        case .unsupportedEditableSVG:
            L10n.text("imageEditor.status.editableSVGImportFailed")
        }
    }
}

nonisolated enum XomoExternalDocumentOpenPolicy {
    static let immediateSplashFileSize = 12 * 1_024 * 1_024
    static let delayedSplashNanoseconds: UInt64 = 180_000_000

    static func kind(for url: URL) -> XomoExternalDocumentKind? {
        switch url.pathExtension.lowercased() {
        case "psd":
            .photoshop
        case "png", "jpg", "jpeg", "tif", "tiff", "heic", "webp":
            .image
        case "svg":
            .editableSVG
        default:
            nil
        }
    }

    static func supports(_ url: URL) -> Bool {
        kind(for: url) != nil
    }

    static func isFigmaWebLocation(_ url: URL) -> Bool {
        url.isFileURL
            && url.pathExtension.caseInsensitiveCompare("webloc") == .orderedSame
    }

    static func shouldShowImmediately(fileSize: Int?) -> Bool {
        guard let fileSize else { return false }
        return fileSize >= immediateSplashFileSize
    }
}

nonisolated struct XomoExternalFigmaLinkImportRequest: Equatable, Identifiable {
    let id: UUID
    let canonicalURL: String
}

@MainActor
enum XomoExternalImageDocumentFactory {
    static func make(sourceName: String, image: NSImage) -> ImageEditorDocument {
        let normalized = image.normalizedBitmapImage()
        let transparentCanvas = NSImage.transparent(size: normalized.size)
        var document = ImageEditorDocument(
            sourceName: sourceName,
            image: transparentCanvas
        )
        var imageLayer = ImageEditorLayer.blank(
            name: editableLayerName(for: sourceName),
            size: normalized.size
        )
        imageLayer.image = normalized
        document.layers = [
            .background(image: transparentCanvas),
            imageLayer,
        ]
        document.selectedLayerID = imageLayer.id
        document.selectedLayerIDs = [imageLayer.id]
        return document
    }

    fileprivate static func editableLayerName(for sourceName: String) -> String {
        let trimmedSourceName = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = (trimmedSourceName as NSString).deletingPathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return baseName.isEmpty
            ? L10n.text("imageEditor.layer.importedFallbackName")
            : baseName
    }
}

@MainActor
enum XomoExternalSVGDocumentFactory {
    static func make(sourceName: String, data: Data) -> ImageEditorDocument? {
        guard let imported = XomoEditableSVGImporter.parse(data) else { return nil }
        let transparentCanvas = NSImage.transparent(size: imported.size)
        var document = ImageEditorDocument(
            sourceName: sourceName,
            image: transparentCanvas
        )
        let shapeLayer = ImageEditorLayer.shape(
            name: XomoExternalImageDocumentFactory.editableLayerName(for: sourceName),
            frame: CGRect(origin: .zero, size: imported.size),
            content: imported.content
        )
        document.layers = [
            .background(image: transparentCanvas),
            shapeLayer,
        ]
        document.selectedLayerID = shapeLayer.id
        document.selectedLayerIDs = [shapeLayer.id]
        return document
    }
}

@MainActor
enum XomoExternalPSDDocumentFactory {
    static func makeFlattenedFallback(
        sourceName: String,
        image: NSImage
    ) -> ImageEditorDocument {
        XomoExternalImageDocumentFactory.make(
            sourceName: sourceName,
            image: image
        )
    }

    static func compatibilityReportForFlattenedFallback(
        parsedReport: ImageEditorPSDCompatibilityReport?,
        image: NSImage
    ) -> ImageEditorPSDCompatibilityReport {
        if let parsedReport {
            return parsedReport.addingFlattenedFallback()
        }

        // The source header could not be trusted. Report the normalized working
        // copy instead of inventing metadata for the original PSD.
        let normalized = image.normalizedBitmapImage()
        return ImageEditorPSDCompatibilityReport(
            width: max(1, Int(normalized.size.width.rounded())),
            height: max(1, Int(normalized.size.height.rounded())),
            bitDepth: 8,
            colorMode: 3,
            layerCount: 1,
            groupCount: 0,
            maskCount: 0,
            compressions: [],
            issues: [
                ImageEditorPSDCompatibilityIssue(kind: .flattenedFallback, count: 1)
            ],
            metadataSource: .flattenedWorkingCopy
        )
    }
}

enum XomoDocumentLoadingStage: Equatable {
    case preparing
    case reading
    case decoding
    case decodingImage
    case decodingVector
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
        case .decodingVector:
            L10n.text("startup.loading.decodingSVG")
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

    typealias ReplacementRequester = @MainActor (
        ImageEditorViewModel,
        @escaping @MainActor () -> Void
    ) -> Void
    typealias RecentDocumentRegistrar = @MainActor (URL) -> Void
    typealias OpenedDocumentWindowActivator = @MainActor () -> Void

    @Published private(set) var presentation: XomoDocumentLoadingPresentation?
    @Published private(set) var editorKeyboardFocusRequestID: UUID?
    @Published private(set) var figmaLinkImportRequest: XomoExternalFigmaLinkImportRequest?

    private let replacementRequester: ReplacementRequester
    private let recentDocumentRegistrar: RecentDocumentRegistrar
    private let openedDocumentWindowActivator: OpenedDocumentWindowActivator
    private weak var viewModel: ImageEditorViewModel?
    private var pendingURL: URL?
    private var activeRequestID: UUID?
    private var activeFileName = ""
    private var activeStage: XomoDocumentLoadingStage = .preparing
    private var loadTask: Task<Void, Never>?
    private var delayedPresentationTask: Task<Void, Never>?

    init(
        replacementRequester: @escaping ReplacementRequester = { viewModel, replacement in
            XomoDocumentReplacementCoordinator.shared.requestReplacement(
                for: viewModel,
                replacement: replacement
            )
        },
        recentDocumentRegistrar: @escaping RecentDocumentRegistrar = {
            XomoRecentDocumentStore.shared.noteOpened($0)
        },
        openedDocumentWindowActivator: @escaping OpenedDocumentWindowActivator = {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.keyWindow?.makeKeyAndOrderFront(nil)
        }
    ) {
        self.replacementRequester = replacementRequester
        self.recentDocumentRegistrar = recentDocumentRegistrar
        self.openedDocumentWindowActivator = openedDocumentWindowActivator
    }

    func register(_ viewModel: ImageEditorViewModel) {
        self.viewModel = viewModel
        startPendingOpenIfPossible()
    }

    func unregister(_ viewModel: ImageEditorViewModel) {
        guard self.viewModel === viewModel else { return }
        self.viewModel = nil
    }

    func fulfillEditorKeyboardFocusRequest(_ requestID: UUID) {
        guard editorKeyboardFocusRequestID == requestID else { return }
        editorKeyboardFocusRequestID = nil
    }

    func fulfillFigmaLinkImportRequest(_ requestID: UUID) {
        guard figmaLinkImportRequest?.id == requestID else { return }
        figmaLinkImportRequest = nil
    }

    func open(_ urls: [URL]) {
        if let documentURL = urls.first(where: XomoExternalDocumentOpenPolicy.supports) {
            open(documentURL)
            return
        }
        guard urls.count == 1,
              let url = urls.first,
              XomoExternalDocumentOpenPolicy.isFigmaWebLocation(url)
        else { return }
        open(url)
    }

    func open(_ url: URL) {
        if XomoExternalDocumentOpenPolicy.isFigmaWebLocation(url) {
            guard let canonicalURL = XomoFigmaWebLocationPolicy.canonicalURL(fromFile: url) else {
                return
            }
            requestFigmaLinkImport(canonicalURL: canonicalURL)
            return
        }
        guard XomoExternalDocumentOpenPolicy.supports(url) else { return }

        guard let viewModel else {
            beginOpen(url)
            return
        }
        replacementRequester(viewModel) { [weak self] in
            self?.beginOpen(url)
        }
    }

    private func beginOpen(_ url: URL) {
        loadTask?.cancel()
        loadTask = nil
        delayedPresentationTask?.cancel()
        delayedPresentationTask = nil
        pendingURL = url
        editorKeyboardFocusRequestID = nil
        figmaLinkImportRequest = nil
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

    private func requestFigmaLinkImport(canonicalURL: String) {
        loadTask?.cancel()
        loadTask = nil
        delayedPresentationTask?.cancel()
        delayedPresentationTask = nil
        pendingURL = nil
        activeRequestID = nil
        presentation = nil
        editorKeyboardFocusRequestID = nil
        figmaLinkImportRequest = XomoExternalFigmaLinkImportRequest(
            id: UUID(),
            canonicalURL: canonicalURL
        )
        openedDocumentWindowActivator()
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
                    XomoExternalImageDocumentFactory.make(
                        sourceName: url.lastPathComponent,
                        image: image
                    )
                )
                finishSuccessfulOpen(url: url, requestID: requestID)
                return
            }

            if documentKind == .editableSVG {
                updateStage(.decodingVector, requestID: requestID)
                guard let document = XomoExternalSVGDocumentFactory.make(
                    sourceName: url.lastPathComponent,
                    data: data
                ) else {
                    throw XomoExternalDocumentOpenError.unsupportedEditableSVG
                }
                try Task.checkCancellation()
                updateStage(.finishing, requestID: requestID)
                await Task.yield()
                guard activeRequestID == requestID else { return }
                viewModel.loadExternalSVGDocument(document)
                finishSuccessfulOpen(url: url, requestID: requestID)
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
                document = XomoExternalPSDDocumentFactory.makeFlattenedFallback(
                    sourceName: url.lastPathComponent,
                    image: flattened
                )
                openedFlattened = true
                compatibilityReport = XomoExternalPSDDocumentFactory
                    .compatibilityReportForFlattenedFallback(
                        parsedReport: compatibilityReport,
                        image: flattened
                    )
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
            finishSuccessfulOpen(url: url, requestID: requestID)
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

    private func finishSuccessfulOpen(url: URL, requestID: UUID) {
        recentDocumentRegistrar(url)
        openedDocumentWindowActivator()
        finish(requestID: requestID)
        guard activeRequestID == nil else { return }
        editorKeyboardFocusRequestID = UUID()
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
