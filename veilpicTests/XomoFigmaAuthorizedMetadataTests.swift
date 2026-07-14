import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct XomoFigmaAuthorizedMetadataTests {
    @Test func personalAccessTokenValidationTrimsEdgesAndRejectsUnsafeValues() throws {
        let token = try XomoFigmaPersonalAccessToken(validating: "  figd_local-test-token_12345  ")

        #expect(token.rawValue == "figd_local-test-token_12345")
        #expect(throws: XomoFigmaAuthorizedMetadataError.invalidCredential) {
            try XomoFigmaPersonalAccessToken(validating: "short")
        }
        #expect(throws: XomoFigmaAuthorizedMetadataError.invalidCredential) {
            try XomoFigmaPersonalAccessToken(validating: "figd_has internal-space")
        }
        #expect(throws: XomoFigmaAuthorizedMetadataError.invalidCredential) {
            try XomoFigmaPersonalAccessToken(validating: "figd_line\nbreak")
        }
    }

    @Test func clientUsesLeastPrivilegeMetadataEndpointAndKeepsTokenOutOfURL() async throws {
        let transport = RecordingFigmaTransport(
            statusCode: 200,
            body: Self.validMetadataResponse
        )
        let client = XomoFigmaMetadataAPIClient(transport: transport)
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout?node-id=32-9"
        )
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")

        let metadata = try await client.fetchMetadata(for: preview, credential: token)
        let request = try #require(transport.lastRequest)

        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "https://api.figma.com/v1/files/abc123DEF456/meta")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "X-Figma-Token") == token.rawValue)
        #expect(request.url?.absoluteString.contains(token.rawValue) == false)
        #expect(metadata.name == "Checkout Flow")
        #expect(metadata.folderName == "Product Design")
        #expect(metadata.editorType == "figma")
        #expect(metadata.version == "987654321")
        #expect(metadata.linkAccess == "view")
    }

    @Test func clientMapsAuthorizationNotFoundRateLimitAndServerFailures() async throws {
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout"
        )
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")
        let expectations: [(Int, XomoFigmaAuthorizedMetadataError)] = [
            (401, .authorizationDenied),
            (403, .authorizationDenied),
            (404, .fileNotFound),
            (429, .rateLimited),
            (503, .serviceUnavailable)
        ]

        for (statusCode, expectedError) in expectations {
            let client = XomoFigmaMetadataAPIClient(
                transport: RecordingFigmaTransport(statusCode: statusCode, body: Data())
            )
            await #expect(throws: expectedError) {
                try await client.fetchMetadata(for: preview, credential: token)
            }
        }
    }

    @Test func clientRejectsOversizedAndMalformedSuccessfulResponses() async throws {
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout"
        )
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")
        let oversized = Data(repeating: 65, count: XomoFigmaMetadataAPIClient.maximumResponseBytes + 1)
        let oversizedClient = XomoFigmaMetadataAPIClient(
            transport: RecordingFigmaTransport(statusCode: 200, body: oversized)
        )
        let malformedClient = XomoFigmaMetadataAPIClient(
            transport: RecordingFigmaTransport(statusCode: 200, body: Data("{}".utf8))
        )

        await #expect(throws: XomoFigmaAuthorizedMetadataError.responseTooLarge) {
            try await oversizedClient.fetchMetadata(for: preview, credential: token)
        }
        await #expect(throws: XomoFigmaAuthorizedMetadataError.invalidResponse) {
            try await malformedClient.fetchMetadata(for: preview, credential: token)
        }
    }

    @Test func controllerNeverReadsNetworkUntilUserExplicitlyConnectsOrRefreshes() async throws {
        let store = InMemoryFigmaCredentialStore()
        let fetcher = RecordingFigmaMetadataFetcher(result: .success(Self.metadata))
        let controller = XomoFigmaAuthorizedMetadataController(store: store, fetcher: fetcher)
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout"
        )

        controller.refreshCredentialState()

        #expect(controller.hasStoredCredential == false)
        #expect(fetcher.calls.isEmpty)

        controller.tokenDraft = "figd_local-test-token_12345"
        await controller.connectAndFetch(preview: preview)

        #expect(controller.hasStoredCredential)
        #expect(controller.tokenDraft.isEmpty)
        #expect(store.savedCredential?.rawValue == "figd_local-test-token_12345")
        #expect(fetcher.calls.map(\.fileKey) == ["abc123DEF456"])
        #expect(controller.state == .loaded(Self.metadata))
    }

    @Test func invalidCredentialDoesNotTouchKeychainOrNetwork() async throws {
        let store = InMemoryFigmaCredentialStore()
        let fetcher = RecordingFigmaMetadataFetcher(result: .success(Self.metadata))
        let controller = XomoFigmaAuthorizedMetadataController(store: store, fetcher: fetcher)
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout"
        )

        controller.tokenDraft = "bad"
        await controller.connectAndFetch(preview: preview)

        #expect(store.saveCount == 0)
        #expect(fetcher.calls.isEmpty)
        #expect(controller.state == .failed(.invalidCredential))
    }

    @Test func changingLinkOrDisconnectingClearsStaleMetadata() async throws {
        let credential = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")
        let store = InMemoryFigmaCredentialStore(savedCredential: credential)
        let fetcher = RecordingFigmaMetadataFetcher(result: .success(Self.metadata))
        let controller = XomoFigmaAuthorizedMetadataController(store: store, fetcher: fetcher)
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout"
        )

        controller.refreshCredentialState()
        await controller.fetchMetadata(preview: preview)
        #expect(controller.state == .loaded(Self.metadata))

        controller.clearMetadata()
        #expect(controller.state == .idle)

        controller.disconnect()
        #expect(controller.hasStoredCredential == false)
        #expect(store.savedCredential == nil)
        #expect(store.deleteCount == 1)
        #expect(controller.state == .idle)
    }

    @Test func sheetUsesSecureCredentialInputAndExplicitNetworkActions() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sheet = try String(
            contentsOf: root.appendingPathComponent("veilpic/XomoFigmaLinkImportSheet.swift"),
            encoding: .utf8
        )
        let keychain = try String(
            contentsOf: root.appendingPathComponent("veilpic/XomoFigmaCredentialStore.swift"),
            encoding: .utf8
        )

        #expect(sheet.contains("SecureField"))
        #expect(sheet.contains("connectAndFetch"))
        #expect(sheet.contains("fetchMetadata"))
        #expect(sheet.contains("disconnect"))
        #expect(sheet.contains("xomo-figma-personal-token"))
        #expect(keychain.contains("kSecAttrAccessibleWhenUnlockedThisDeviceOnly"))
        #expect(keychain.contains("kSecAttrSynchronizable"))
        #expect(!keychain.contains("UserDefaults"))
    }

    private static let validMetadataResponse = Data(
        """
        {
          "file": {
            "name": "Checkout Flow",
            "folder_name": "Product Design",
            "last_touched_at": "2026-07-14T12:34:56Z",
            "editorType": "figma",
            "version": "987654321",
            "role": "viewer",
            "link_access": "view",
            "url": "https://www.figma.com/design/abc123DEF456/Checkout"
          }
        }
        """.utf8
    )

    private static let metadata = XomoFigmaOfficialFileMetadata(
        name: "Checkout Flow",
        folderName: "Product Design",
        lastTouchedAt: "2026-07-14T12:34:56Z",
        editorType: "figma",
        version: "987654321",
        role: "viewer",
        linkAccess: "view"
    )
}

private final class RecordingFigmaTransport: XomoFigmaHTTPTransport {
    private(set) var lastRequest: URLRequest?
    let statusCode: Int
    let body: Data

    init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = try #require(
            HTTPURLResponse(
                url: request.url ?? URL(string: "https://api.figma.com")!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        )
        return (body, response)
    }
}

@MainActor
private final class InMemoryFigmaCredentialStore: XomoFigmaCredentialStoring {
    var savedCredential: XomoFigmaPersonalAccessToken?
    private(set) var saveCount = 0
    private(set) var deleteCount = 0

    init(savedCredential: XomoFigmaPersonalAccessToken? = nil) {
        self.savedCredential = savedCredential
    }

    func load() throws -> XomoFigmaPersonalAccessToken? {
        savedCredential
    }

    func save(_ credential: XomoFigmaPersonalAccessToken) throws {
        saveCount += 1
        savedCredential = credential
    }

    func delete() throws {
        deleteCount += 1
        savedCredential = nil
    }
}

@MainActor
private final class RecordingFigmaMetadataFetcher: XomoFigmaMetadataFetching {
    struct Call: Equatable {
        var fileKey: String
        var credential: String
    }

    private(set) var calls: [Call] = []
    let result: Result<XomoFigmaOfficialFileMetadata, XomoFigmaAuthorizedMetadataError>

    init(result: Result<XomoFigmaOfficialFileMetadata, XomoFigmaAuthorizedMetadataError>) {
        self.result = result
    }

    func fetchMetadata(
        for preview: XomoFigmaLinkPreview,
        credential: XomoFigmaPersonalAccessToken
    ) async throws -> XomoFigmaOfficialFileMetadata {
        calls.append(Call(fileKey: preview.fileKey, credential: credential.rawValue))
        return try result.get()
    }
}
