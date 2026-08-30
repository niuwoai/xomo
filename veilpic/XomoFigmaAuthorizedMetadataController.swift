import Combine
import SwiftUI

enum XomoFigmaAuthorizedMetadataState: Equatable {
    case idle
    case loading
    case loaded(XomoFigmaOfficialFileMetadata)
    case failed(XomoFigmaAuthorizedMetadataError)
}

@MainActor
final class XomoFigmaAuthorizedMetadataController: ObservableObject {
    @Published var tokenDraft = ""
    @Published private(set) var hasStoredCredential = false
    @Published private(set) var state: XomoFigmaAuthorizedMetadataState = .idle

    private let store: any XomoFigmaCredentialStoring
    private let fetcher: any XomoFigmaMetadataFetching
    private var requestGeneration = UUID()

    init() {
        store = XomoFigmaKeychainCredentialStore()
        fetcher = XomoFigmaMetadataAPIClient()
    }

    init(store: any XomoFigmaCredentialStoring, fetcher: any XomoFigmaMetadataFetching) {
        self.store = store
        self.fetcher = fetcher
    }

    var isLoading: Bool {
        state == .loading
    }

    func refreshCredentialState() {
        do {
            hasStoredCredential = try store.load() != nil
        } catch {
            requestGeneration = UUID()
            hasStoredCredential = false
            state = .failed(.secureStorageUnavailable)
        }
    }

    func connectAndFetch(preview: XomoFigmaLinkPreview) async {
        let generation = UUID()
        requestGeneration = generation
        let credential: XomoFigmaPersonalAccessToken
        do {
            credential = try XomoFigmaPersonalAccessToken(validating: tokenDraft)
        } catch {
            state = .failed(.invalidCredential)
            return
        }

        do {
            try store.save(credential)
        } catch {
            state = .failed(.secureStorageUnavailable)
            return
        }

        tokenDraft = ""
        hasStoredCredential = true
        await performFetch(preview: preview, credential: credential, generation: generation)
    }

    func fetchMetadata(preview: XomoFigmaLinkPreview) async {
        let generation = UUID()
        requestGeneration = generation
        let credential: XomoFigmaPersonalAccessToken
        do {
            guard let storedCredential = try store.load() else {
                hasStoredCredential = false
                state = .failed(.credentialMissing)
                return
            }
            credential = storedCredential
            hasStoredCredential = true
        } catch {
            state = .failed(.secureStorageUnavailable)
            return
        }
        await performFetch(preview: preview, credential: credential, generation: generation)
    }

    func clearMetadata() {
        requestGeneration = UUID()
        state = .idle
    }

    func disconnect() {
        requestGeneration = UUID()
        do {
            try store.delete()
            hasStoredCredential = false
            tokenDraft = ""
            state = .idle
        } catch {
            state = .failed(.secureStorageUnavailable)
        }
    }

    private func performFetch(
        preview: XomoFigmaLinkPreview,
        credential: XomoFigmaPersonalAccessToken,
        generation: UUID
    ) async {
        guard requestGeneration == generation else { return }
        state = .loading
        do {
            let metadata = try await fetcher.fetchMetadata(for: preview, credential: credential)
            guard requestGeneration == generation else { return }
            state = .loaded(metadata)
        } catch let knownError as XomoFigmaAuthorizedMetadataError {
            guard requestGeneration == generation else { return }
            state = .failed(knownError)
        } catch {
            guard requestGeneration == generation else { return }
            state = .failed(.transportFailed)
        }
    }
}
