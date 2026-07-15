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

struct XomoFigmaVariableColor: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    var planColor: XomoFigmaPlanColor {
        XomoFigmaPlanColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

enum XomoFigmaVariableModeValue: Decodable, Equatable, Sendable {
    case color(XomoFigmaVariableColor)
    case alias(String)
    case boolean(Bool)
    case number(Double)
    case string(String)

    init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: DynamicCodingKey.self),
           let type = try keyed.decodeIfPresent(String.self, forKey: DynamicCodingKey(stringValue: "type")),
           type == "VARIABLE_ALIAS",
           let id = try keyed.decodeIfPresent(String.self, forKey: DynamicCodingKey(stringValue: "id")),
           !id.isEmpty {
            self = .alias(id)
            return
        }

        if let keyed = try? decoder.container(keyedBy: DynamicCodingKey.self),
           keyed.contains(DynamicCodingKey(stringValue: "r")),
           keyed.contains(DynamicCodingKey(stringValue: "g")),
           keyed.contains(DynamicCodingKey(stringValue: "b")) {
            let red = try keyed.decode(Double.self, forKey: DynamicCodingKey(stringValue: "r"))
            let green = try keyed.decode(Double.self, forKey: DynamicCodingKey(stringValue: "g"))
            let blue = try keyed.decode(Double.self, forKey: DynamicCodingKey(stringValue: "b"))
            let alpha = try keyed.decodeIfPresent(Double.self, forKey: DynamicCodingKey(stringValue: "a")) ?? 1
            guard [red, green, blue, alpha].allSatisfy(\.isFinite) else { throw DecodingError.dataCorruptedError(
                forKey: DynamicCodingKey(stringValue: "r"), in: keyed, debugDescription: "Non-finite Figma color"
            ) }
            self = .color(XomoFigmaVariableColor(
                red: min(max(red, 0), 1),
                green: min(max(green, 0), 1),
                blue: min(max(blue, 0), 1),
                alpha: min(max(alpha, 0), 1)
            ))
            return
        }

        let single = try decoder.singleValueContainer()
        if let value = try? single.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? single.decode(Double.self) {
            self = .number(value)
        } else if let value = try? single.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.dataCorruptedError(in: single, debugDescription: "Unsupported Figma variable value")
        }
    }
}

struct XomoFigmaVariableStore: Equatable, Sendable {
    struct Definition: Equatable, Sendable {
        var id: String
        var variableCollectionID: String
        var valuesByMode: [String: XomoFigmaVariableModeValue]
    }

    struct Collection: Equatable, Sendable {
        var defaultModeID: String
        var modeIDs: [String]
    }

    var variables: [String: Definition]
    var collections: [String: Collection]

    func color(for variableID: String) -> XomoFigmaPlanColor? {
        color(for: variableID, visited: [])
    }

    private func color(for variableID: String, visited: Set<String>) -> XomoFigmaPlanColor? {
        guard !visited.contains(variableID), let definition = variables[variableID] else { return nil }
        let nextVisited = visited.union([variableID])
        let modeIDs = preferredModeIDs(for: definition)
        for modeID in modeIDs {
            guard let value = definition.valuesByMode[modeID] else { continue }
            switch value {
            case .color(let color):
                return color.planColor
            case .alias(let aliasID):
                return color(for: aliasID, visited: nextVisited)
            case .boolean, .number, .string:
                continue
            }
        }
        return nil
    }

    private func preferredModeIDs(for definition: Definition) -> [String] {
        guard let collection = collections[definition.variableCollectionID] else {
            return definition.valuesByMode.keys.sorted()
        }
        return [collection.defaultModeID] + collection.modeIDs.filter { $0 != collection.defaultModeID }
    }
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
protocol XomoFigmaVariableFetching {
    func fetchVariables(
        fileKey: String,
        credential: XomoFigmaPersonalAccessToken
    ) async throws -> XomoFigmaVariableStore
}

@MainActor
struct XomoFigmaVariableAPIClient: XomoFigmaVariableFetching {
    static let maximumResponseBytes = 10_000_000

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

    func fetchVariables(
        fileKey: String,
        credential: XomoFigmaPersonalAccessToken
    ) async throws -> XomoFigmaVariableStore {
        let endpoint = baseURL
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("files", isDirectory: true)
            .appendingPathComponent(fileKey, isDirectory: true)
            .appendingPathComponent("variables", isDirectory: true)
            .appendingPathComponent("local", isDirectory: false)
        var request = URLRequest(
            url: endpoint,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(credential.rawValue, forHTTPHeaderField: "X-Figma-Token")

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
            let envelope = try JSONDecoder().decode(VariablesEnvelope.self, from: data)
            return envelope.meta.store
        } catch {
            throw XomoFigmaAuthorizedMetadataError.invalidResponse
        }
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

private struct DynamicCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private struct VariablesEnvelope: Decodable {
    var meta: VariablesMeta
}

private struct VariablesMeta: Decodable {
    var variables: [String: VariableDefinition]
    var variableCollections: [String: VariableCollection]

    var store: XomoFigmaVariableStore {
        XomoFigmaVariableStore(
            variables: variables.mapValues { definition in
                XomoFigmaVariableStore.Definition(
                    id: definition.id,
                    variableCollectionID: definition.variableCollectionID,
                    valuesByMode: definition.valuesByMode
                )
            },
            collections: variableCollections.mapValues { collection in
                XomoFigmaVariableStore.Collection(
                    defaultModeID: collection.defaultModeID,
                    modeIDs: collection.modes.map(\.modeID)
                )
            }
        )
    }
}

private struct VariableDefinition: Decodable {
    var id: String
    var variableCollectionID: String
    var valuesByMode: [String: XomoFigmaVariableModeValue]

    enum CodingKeys: String, CodingKey {
        case id
        case variableCollectionID = "variableCollectionId"
        case valuesByMode
    }
}

private struct VariableCollection: Decodable {
    var defaultModeID: String
    var modes: [VariableMode]

    enum CodingKeys: String, CodingKey {
        case defaultModeID = "defaultModeId"
        case modes
    }
}

private struct VariableMode: Decodable {
    var modeID: String

    enum CodingKeys: String, CodingKey {
        case modeID = "modeId"
    }
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
