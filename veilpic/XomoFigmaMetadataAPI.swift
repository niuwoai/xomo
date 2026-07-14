import Foundation

struct XomoFigmaPersonalAccessToken: Equatable {
    static let minimumLength = 8
    static let maximumLength = 4_096

    let rawValue: String

    init(validating input: String) throws {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (Self.minimumLength...Self.maximumLength).contains(value.count),
              value.unicodeScalars.allSatisfy({ (33...126).contains($0.value) })
        else {
            throw XomoFigmaAuthorizedMetadataError.invalidCredential
        }
        rawValue = value
    }
}

struct XomoFigmaOfficialFileMetadata: Equatable, Sendable {
    var name: String
    var folderName: String?
    var lastTouchedAt: String?
    var editorType: String?
    var version: String?
    var role: String?
    var linkAccess: String?
}

enum XomoFigmaAuthorizedMetadataError: Error, Equatable, CaseIterable, Sendable {
    case invalidCredential
    case secureStorageUnavailable
    case credentialMissing
    case invalidResponse
    case authorizationDenied
    case fileNotFound
    case rateLimited
    case serviceUnavailable
    case responseTooLarge
    case transportFailed

    var localizationKey: String {
        switch self {
        case .invalidCredential:
            "xomo.figma.metadata.error.invalidCredential"
        case .secureStorageUnavailable:
            "xomo.figma.metadata.error.secureStorageUnavailable"
        case .credentialMissing:
            "xomo.figma.metadata.error.credentialMissing"
        case .invalidResponse:
            "xomo.figma.metadata.error.invalidResponse"
        case .authorizationDenied:
            "xomo.figma.metadata.error.authorizationDenied"
        case .fileNotFound:
            "xomo.figma.metadata.error.fileNotFound"
        case .rateLimited:
            "xomo.figma.metadata.error.rateLimited"
        case .serviceUnavailable:
            "xomo.figma.metadata.error.serviceUnavailable"
        case .responseTooLarge:
            "xomo.figma.metadata.error.responseTooLarge"
        case .transportFailed:
            "xomo.figma.metadata.error.transportFailed"
        }
    }
}

protocol XomoFigmaHTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

final class XomoFigmaURLSessionTransport: XomoFigmaHTTPTransport {
    private let session: URLSession

    init(session: URLSession? = nil) {
        self.session = session ?? Self.makeSecureSession()
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }

    private static func makeSecureSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        let delegate = XomoFigmaNoRedirectSessionDelegate()
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
}

private final class XomoFigmaNoRedirectSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

@MainActor
protocol XomoFigmaMetadataFetching {
    func fetchMetadata(
        for preview: XomoFigmaLinkPreview,
        credential: XomoFigmaPersonalAccessToken
    ) async throws -> XomoFigmaOfficialFileMetadata
}

@MainActor
struct XomoFigmaMetadataAPIClient: XomoFigmaMetadataFetching {
    static let maximumResponseBytes = 2_000_000

    private let baseURL: URL
    private let transport: any XomoFigmaHTTPTransport

    init() {
        baseURL = URL(string: "https://api.figma.com")!
        transport = XomoFigmaURLSessionTransport()
    }

    init(baseURL: URL = URL(string: "https://api.figma.com")!, transport: any XomoFigmaHTTPTransport) {
        self.baseURL = baseURL
        self.transport = transport
    }

    func fetchMetadata(
        for preview: XomoFigmaLinkPreview,
        credential: XomoFigmaPersonalAccessToken
    ) async throws -> XomoFigmaOfficialFileMetadata {
        let request = makeRequest(fileKey: preview.fileKey, credential: credential)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch let knownError as XomoFigmaAuthorizedMetadataError {
            throw knownError
        } catch {
            throw XomoFigmaAuthorizedMetadataError.transportFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw XomoFigmaAuthorizedMetadataError.invalidResponse
        }
        try validateStatusCode(httpResponse.statusCode)
        guard data.count <= Self.maximumResponseBytes else {
            throw XomoFigmaAuthorizedMetadataError.responseTooLarge
        }

        do {
            let envelope = try JSONDecoder().decode(MetadataEnvelope.self, from: data)
            return envelope.file.metadata
        } catch {
            throw XomoFigmaAuthorizedMetadataError.invalidResponse
        }
    }

    private func makeRequest(
        fileKey: String,
        credential: XomoFigmaPersonalAccessToken
    ) -> URLRequest {
        let endpoint = baseURL
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("files", isDirectory: true)
            .appendingPathComponent(fileKey, isDirectory: true)
            .appendingPathComponent("meta", isDirectory: false)
        var request = URLRequest(
            url: endpoint,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 20
        )
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(credential.rawValue, forHTTPHeaderField: "X-Figma-Token")
        return request
    }

    private func validateStatusCode(_ statusCode: Int) throws {
        switch statusCode {
        case 200:
            return
        case 401, 403:
            throw XomoFigmaAuthorizedMetadataError.authorizationDenied
        case 404:
            throw XomoFigmaAuthorizedMetadataError.fileNotFound
        case 429:
            throw XomoFigmaAuthorizedMetadataError.rateLimited
        case 500...599:
            throw XomoFigmaAuthorizedMetadataError.serviceUnavailable
        default:
            throw XomoFigmaAuthorizedMetadataError.invalidResponse
        }
    }
}

private struct MetadataEnvelope: Decodable {
    var file: MetadataFile
}

private struct MetadataFile: Decodable {
    var name: String
    var folderName: String?
    var lastTouchedAt: String?
    var editorType: String?
    var version: String?
    var role: String?
    var linkAccess: String?

    enum CodingKeys: String, CodingKey {
        case name
        case folderName = "folder_name"
        case lastTouchedAt = "last_touched_at"
        case editorType
        case version
        case role
        case linkAccess = "link_access"
    }

    var metadata: XomoFigmaOfficialFileMetadata {
        XomoFigmaOfficialFileMetadata(
            name: name,
            folderName: folderName,
            lastTouchedAt: lastTouchedAt,
            editorType: editorType,
            version: version,
            role: role,
            linkAccess: linkAccess
        )
    }
}
