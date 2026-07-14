import Foundation
import ImageIO
import Network

@MainActor
protocol XomoFigmaImageAssetFetching {
    func fetchAssets(
        fileKey: String,
        references: Set<String>,
        credential: XomoFigmaPersonalAccessToken
    ) async throws -> [String: XomoFigmaImageAsset]
}

@MainActor
struct XomoFigmaImageAssetAPIClient: XomoFigmaImageAssetFetching {
    static let maximumReferenceCount = 24
    static let maximumManifestBytes = 2_000_000
    static let maximumAssetBytes = 20_000_000
    static let maximumTotalAssetBytes = 80_000_000
    static let maximumPixelDimension = 16_384
    static let maximumPixelCount = 64_000_000

    private let baseURL: URL
    private let transport: any XomoFigmaHTTPTransport

    init() {
        baseURL = URL(string: "https://api.figma.com")!
        transport = XomoFigmaURLSessionTransport()
    }

    init(
        baseURL: URL = URL(string: "https://api.figma.com")!,
        transport: any XomoFigmaHTTPTransport
    ) {
        self.baseURL = baseURL
        self.transport = transport
    }

    func fetchAssets(
        fileKey: String,
        references: Set<String>,
        credential: XomoFigmaPersonalAccessToken
    ) async throws -> [String: XomoFigmaImageAsset] {
        let boundedReferences = references
            .filter(Self.isSafeReference)
            .sorted()
            .prefix(Self.maximumReferenceCount)
        guard !boundedReferences.isEmpty else { return [:] }

        let manifestRequest = makeManifestRequest(fileKey: fileKey, credential: credential)
        let manifestData: Data
        let manifestResponse: URLResponse
        do {
            (manifestData, manifestResponse) = try await transport.data(for: manifestRequest)
        } catch {
            throw XomoFigmaNodeImportError.transportFailed
        }
        try validateAPIResponse(manifestResponse)
        guard manifestData.count <= Self.maximumManifestBytes else {
            throw XomoFigmaNodeImportError.responseTooLarge
        }

        let manifest: XomoFigmaImageAssetManifest
        do {
            manifest = try JSONDecoder().decode(XomoFigmaImageAssetManifest.self, from: manifestData)
        } catch {
            throw XomoFigmaNodeImportError.invalidResponse
        }

        var assets: [String: XomoFigmaImageAsset] = [:]
        var totalBytes = 0
        for reference in boundedReferences {
            guard let rawURL = manifest.images[reference] ?? nil,
                  let assetURL = Self.safeAssetURL(rawURL)
            else { continue }
            guard let asset = await fetchAsset(url: assetURL, remainingByteBudget: Self.maximumTotalAssetBytes - totalBytes)
            else { continue }
            totalBytes += asset.data.count
            assets[reference] = asset
        }
        return assets
    }

    private func makeManifestRequest(
        fileKey: String,
        credential: XomoFigmaPersonalAccessToken
    ) -> URLRequest {
        let endpoint = baseURL
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("files", isDirectory: true)
            .appendingPathComponent(fileKey, isDirectory: true)
            .appendingPathComponent("images", isDirectory: false)
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

    private func fetchAsset(url: URL, remainingByteBudget: Int) async -> XomoFigmaImageAsset? {
        guard remainingByteBudget > 0 else { return nil }
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )
        request.httpMethod = "GET"
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch {
            return nil
        }
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              data.count <= Self.maximumAssetBytes,
              data.count <= remainingByteBudget,
              Self.isAcceptableImageMIMEType(response.mimeType),
              let pixelSize = Self.validatedPixelSize(data)
        else { return nil }
        return XomoFigmaImageAsset(data: data, pixelSize: pixelSize)
    }

    private func validateAPIResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw XomoFigmaNodeImportError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200:
            return
        case 400:
            throw XomoFigmaNodeImportError.invalidRequest
        case 401, 403:
            throw XomoFigmaNodeImportError.authorizationDenied
        case 404:
            throw XomoFigmaNodeImportError.fileNotFound
        case 429:
            throw XomoFigmaNodeImportError.rateLimited
        case 500...599:
            throw XomoFigmaNodeImportError.serviceUnavailable
        default:
            throw XomoFigmaNodeImportError.invalidResponse
        }
    }

    private static func isSafeReference(_ reference: String) -> Bool {
        !reference.isEmpty
            && reference.count <= 512
            && !reference.unicodeScalars.contains { $0.value < 32 || $0.value == 127 }
    }

    private static func safeAssetURL(_ rawValue: String) -> URL? {
        guard rawValue.count <= 4_096,
              let components = URLComponents(string: rawValue),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil,
              host != "localhost",
              !host.hasSuffix(".localhost"),
              !host.hasSuffix(".local"),
              IPv4Address(host) == nil,
              IPv6Address(host) == nil,
              let url = components.url
        else { return nil }
        return url
    }

    private static func isAcceptableImageMIMEType(_ mimeType: String?) -> Bool {
        guard let mimeType = mimeType?.lowercased() else { return true }
        return mimeType.hasPrefix("image/") || mimeType == "application/octet-stream"
    }

    private static func validatedPixelSize(_ data: Data) -> XomoFigmaPlanSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0,
              height > 0,
              width <= Self.maximumPixelDimension,
              height <= Self.maximumPixelDimension,
              width <= Self.maximumPixelCount / height
        else { return nil }
        return XomoFigmaPlanSize(width: Double(width), height: Double(height))
    }
}

private struct XomoFigmaImageAssetManifest: Decodable {
    var images: [String: String?]
}
