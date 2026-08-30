import Combine
import Foundation

enum XomoFigmaNodeImportState: Equatable {
    case idle
    case loading
    case loaded(XomoFigmaNodeImportPlan)
    case failed(XomoFigmaNodeImportError)
}

@MainActor
final class XomoFigmaNodeImportController: ObservableObject {
    @Published private(set) var state: XomoFigmaNodeImportState = .idle

    private let store: any XomoFigmaCredentialStoring
    private let fetcher: any XomoFigmaNodePlanFetching
    private var requestGeneration = UUID()

    init() {
        store = XomoFigmaKeychainCredentialStore()
        fetcher = XomoFigmaNodeContentAPIClient()
    }

    init(store: any XomoFigmaCredentialStoring, fetcher: any XomoFigmaNodePlanFetching) {
        self.store = store
        self.fetcher = fetcher
    }

    var isLoading: Bool {
        state == .loading
    }

    func fetchPlan(preview: XomoFigmaLinkPreview) async {
        guard !Task.isCancelled else { return }
        // Every new read supersedes the previous one, including rejected reads.
        let generation = UUID()
        requestGeneration = generation
        guard preview.nodeID != nil else {
            state = .failed(.nodeSelectionRequired)
            return
        }
        let credential: XomoFigmaPersonalAccessToken
        do {
            guard let storedCredential = try store.load() else {
                state = .failed(.credentialMissing)
                return
            }
            credential = storedCredential
        } catch {
            state = .failed(.secureStorageUnavailable)
            return
        }

        state = .loading
        do {
            let plan = try await fetcher.fetchPlan(for: preview, credential: credential)
            try Task.checkCancellation()
            guard requestGeneration == generation else { return }
            state = .loaded(plan)
        } catch let knownError as XomoFigmaNodeImportError {
            guard requestGeneration == generation else { return }
            state = Task.isCancelled ? .idle : .failed(knownError)
        } catch {
            guard requestGeneration == generation else { return }
            state = Task.isCancelled || error is CancellationError ? .idle : .failed(.transportFailed)
        }
    }

    func clear() {
        requestGeneration = UUID()
        state = .idle
    }
}
