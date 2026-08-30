import Foundation
import Testing
@testable import musepic

@MainActor
struct XomoFigmaRequestGenerationTests {
    enum MetadataFailure: CaseIterable, Sendable {
        case invalidDraft, saveFailure, missingCredential, loadFailure

        var expected: XomoFigmaAuthorizedMetadataError {
            switch self {
            case .invalidDraft: .invalidCredential
            case .missingCredential: .credentialMissing
            case .saveFailure, .loadFailure: .secureStorageUnavailable
            }
        }
    }

    enum NodeFailure: CaseIterable, Sendable {
        case missingNode, missingCredential, loadFailure

        var expected: XomoFigmaNodeImportError {
            switch self {
            case .missingNode: .nodeSelectionRequired
            case .missingCredential: .credentialMissing
            case .loadFailure: .secureStorageUnavailable
            }
        }
    }

    @Test(arguments: MetadataFailure.allCases, [false, true])
    func metadataPreflightFailureInvalidatesOldResponse(failure: MetadataFailure, oldFails: Bool) async throws {
        let store = try GenerationCredentialStore()
        let fetcher = GenerationFetcher()
        let controller = XomoFigmaAuthorizedMetadataController(store: store, fetcher: fetcher)
        let preview = try preview()
        let old = Task { await controller.fetchMetadata(preview: preview) }
        await fetcher.metadata.waitForCalls(1)
        switch failure {
        case .invalidDraft:
            controller.tokenDraft = "short"
            await controller.connectAndFetch(preview: preview)
        case .saveFailure:
            store.saveFails = true
            controller.tokenDraft = "local-fixture-token"
            await controller.connectAndFetch(preview: preview)
        case .missingCredential:
            store.credential = nil
            await controller.fetchMetadata(preview: preview)
        case .loadFailure:
            store.loadFails = true
            await controller.fetchMetadata(preview: preview)
        }
        #expect(controller.state == .failed(failure.expected))
        fetcher.metadata.resolve(oldFails ? .failure(XomoFigmaAuthorizedMetadataError.serviceUnavailable) : .success(metadata("old")))
        await old.value
        #expect(controller.state == .failed(failure.expected))
        #expect(fetcher.metadata.calls == 1)
        #expect(!controller.isLoading)
    }

    @Test(arguments: NodeFailure.allCases, [false, true])
    func nodePreflightFailureInvalidatesOldPlan(failure: NodeFailure, oldFails: Bool) async throws {
        let store = try GenerationCredentialStore()
        let fetcher = GenerationFetcher()
        let controller = XomoFigmaNodeImportController(store: store, fetcher: fetcher)
        let preview = try preview()
        var nextPreview = preview
        let old = Task { await controller.fetchPlan(preview: preview) }
        await fetcher.plans.waitForCalls(1)
        switch failure {
        case .missingNode: nextPreview.nodeID = nil
        case .missingCredential: store.credential = nil
        case .loadFailure: store.loadFails = true
        }
        await controller.fetchPlan(preview: nextPreview)
        #expect(controller.state == .failed(failure.expected))
        fetcher.plans.resolve(oldFails ? .failure(XomoFigmaNodeImportError.fileNotFound) : .success(plan("old")))
        await old.value
        #expect(controller.state == .failed(failure.expected))
        #expect(fetcher.plans.calls == 1)
        #expect(!controller.isLoading)
    }

    @Test(arguments: [false, true])
    func newestSuccessfulMetadataSurvivesOlderCompletion(oldFails: Bool) async throws {
        let store = try GenerationCredentialStore()
        let fetcher = GenerationFetcher()
        let controller = XomoFigmaAuthorizedMetadataController(store: store, fetcher: fetcher)
        let preview = try preview()
        let old = Task { await controller.fetchMetadata(preview: preview) }
        await fetcher.metadata.waitForCalls(1)
        let newest = Task { await controller.fetchMetadata(preview: preview) }
        await fetcher.metadata.waitForCalls(2)
        fetcher.metadata.resolve(.success(metadata("new")), at: 1)
        await newest.value
        fetcher.metadata.resolve(oldFails ? .failure(GenerationFixtureError.transport) : .success(metadata("old")))
        await old.value
        #expect(controller.state == .loaded(metadata("new")))
    }

    @Test(arguments: [false, true])
    func newestSuccessfulPlanSurvivesOlderCompletion(oldFails: Bool) async throws {
        let store = try GenerationCredentialStore()
        let fetcher = GenerationFetcher()
        let controller = XomoFigmaNodeImportController(store: store, fetcher: fetcher)
        let preview = try preview()
        let old = Task { await controller.fetchPlan(preview: preview) }
        await fetcher.plans.waitForCalls(1)
        let newest = Task { await controller.fetchPlan(preview: preview) }
        await fetcher.plans.waitForCalls(2)
        fetcher.plans.resolve(.success(plan("new")), at: 1)
        await newest.value
        fetcher.plans.resolve(oldFails ? .failure(GenerationFixtureError.transport) : .success(plan("old")))
        await old.value
        #expect(controller.state == .loaded(plan("new")))
    }

    @Test(arguments: [false, true])
    func metadataClearOrDisconnectRejectsLateResponse(disconnect: Bool) async throws {
        let store = try GenerationCredentialStore()
        let fetcher = GenerationFetcher()
        let controller = XomoFigmaAuthorizedMetadataController(store: store, fetcher: fetcher)
        let preview = try preview()
        let old = Task { await controller.fetchMetadata(preview: preview) }
        await fetcher.metadata.waitForCalls(1)
        if disconnect { controller.disconnect() } else { controller.clearMetadata() }
        fetcher.metadata.resolve(.success(metadata("old")))
        await old.value
        #expect(controller.state == .idle)
        if disconnect { #expect(!controller.hasStoredCredential) }
    }

    @Test func clearingPlanRejectsLateResponse() async throws {
        let store = try GenerationCredentialStore()
        let fetcher = GenerationFetcher()
        let controller = XomoFigmaNodeImportController(store: store, fetcher: fetcher)
        let preview = try preview()
        let old = Task { await controller.fetchPlan(preview: preview) }
        await fetcher.plans.waitForCalls(1)
        controller.clear()
        fetcher.plans.resolve(.success(plan("old")))
        await old.value
        #expect(controller.state == .idle)
    }

    @Test(arguments: [false, true])
    func credentialRefreshFailureInvalidatesPendingMetadata(oldFails: Bool) async throws {
        let store = try GenerationCredentialStore()
        let fetcher = GenerationFetcher()
        let controller = XomoFigmaAuthorizedMetadataController(store: store, fetcher: fetcher)
        let preview = try preview()
        let old = Task { await controller.fetchMetadata(preview: preview) }
        await fetcher.metadata.waitForCalls(1)
        store.loadFails = true
        controller.refreshCredentialState()
        fetcher.metadata.resolve(oldFails ? .failure(GenerationFixtureError.transport) : .success(metadata("old")))
        await old.value
        #expect(controller.state == .failed(.secureStorageUnavailable))
        #expect(!controller.hasStoredCredential)
    }

    @Test func successfulCredentialRefreshDoesNotDiscardPendingMetadata() async throws {
        let store = try GenerationCredentialStore()
        let fetcher = GenerationFetcher()
        let controller = XomoFigmaAuthorizedMetadataController(store: store, fetcher: fetcher)
        let preview = try preview()
        let old = Task { await controller.fetchMetadata(preview: preview) }
        await fetcher.metadata.waitForCalls(1)
        controller.refreshCredentialState()
        #expect(controller.isLoading)
        fetcher.metadata.resolve(.success(metadata("current")))
        await old.value
        #expect(controller.state == .loaded(metadata("current")))
        #expect(controller.hasStoredCredential)
    }

    private func preview() throws -> XomoFigmaLinkPreview {
        try XomoFigmaLinkParser.parse("https://www.figma.com/design/abc123DEF456/Fixture?node-id=1-3")
    }

    private func metadata(_ name: String) -> XomoFigmaOfficialFileMetadata {
        XomoFigmaOfficialFileMetadata(name: name, folderName: nil, lastTouchedAt: nil,
            editorType: nil, version: nil, role: nil, linkAccess: nil)
    }

    private func plan(_ name: String) -> XomoFigmaNodeImportPlan {
        XomoFigmaNodeImportPlan(fileName: name, version: nil, rootSourceID: "1:3", rootName: name, items: [])
    }
}

private enum GenerationFixtureError: Error { case storage, transport }

@MainActor
private final class GenerationCredentialStore: XomoFigmaCredentialStoring {
    var credential: XomoFigmaPersonalAccessToken?
    var loadFails = false
    var saveFails = false

    init() throws { credential = try XomoFigmaPersonalAccessToken(validating: "local-fixture-token") }
    func load() throws -> XomoFigmaPersonalAccessToken? {
        if loadFails { throw GenerationFixtureError.storage }
        return credential
    }
    func save(_ value: XomoFigmaPersonalAccessToken) throws {
        if saveFails { throw GenerationFixtureError.storage }
        credential = value
    }
    func delete() throws { credential = nil }
}

@MainActor
private final class GenerationFetcher: XomoFigmaMetadataFetching, XomoFigmaNodePlanFetching {
    let metadata = DeferredGenerationResult<XomoFigmaOfficialFileMetadata>()
    let plans = DeferredGenerationResult<XomoFigmaNodeImportPlan>()

    func fetchMetadata(for preview: XomoFigmaLinkPreview, credential: XomoFigmaPersonalAccessToken) async throws -> XomoFigmaOfficialFileMetadata {
        try await metadata.value()
    }
    func fetchPlan(for preview: XomoFigmaLinkPreview, credential: XomoFigmaPersonalAccessToken) async throws -> XomoFigmaNodeImportPlan {
        try await plans.value()
    }
}

@MainActor
private final class DeferredGenerationResult<Value: Sendable> {
    private(set) var calls = 0
    private var pending: [CheckedContinuation<Value, Error>] = []
    private var waiter: (count: Int, continuation: CheckedContinuation<Void, Never>)?

    func value() async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            pending.append(continuation)
            calls += 1
            if let waiter, calls >= waiter.count {
                self.waiter = nil
                waiter.continuation.resume()
            }
        }
    }

    func waitForCalls(_ count: Int) async {
        guard calls < count else { return }
        await withCheckedContinuation { waiter = (count, $0) }
    }

    func resolve(_ result: Result<Value, Error>, at index: Int = 0) {
        pending.remove(at: index).resume(with: result)
    }
}
