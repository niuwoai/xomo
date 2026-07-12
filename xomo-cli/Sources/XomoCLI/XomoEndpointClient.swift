import Darwin
import Foundation

struct XomoEndpoint: Decodable {
    let host: String
    let port: UInt16
    let token: String
    let pid: Int32
    let version: String
}

enum XomoEndpointClientError: LocalizedError {
    case endpointMissing([String])
    case endpointInvalid(String)
    case connectionFailed(String)
    case requestFailed(String)
    case responseInvalid(String)

    var errorDescription: String? {
        switch self {
        case .endpointMissing(let paths):
            "Xomo is not running or automation endpoint is unavailable. Checked: \(paths.joined(separator: ", "))"
        case .endpointInvalid(let message): "Invalid Xomo endpoint: \(message)"
        case .connectionFailed(let message): "Cannot connect to Xomo: \(message)"
        case .requestFailed(let message): "Xomo request failed: \(message)"
        case .responseInvalid(let message): "Invalid Xomo response: \(message)"
        }
    }
}

struct XomoEndpointClient {
    private static let maximumResponseBytes = 256 * 1024 * 1024
    let endpoint: XomoEndpoint

    init() throws {
        let urls = Self.endpointURLs
        var lastError: Error?
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            do {
                let candidate = try JSONDecoder().decode(XomoEndpoint.self, from: Data(contentsOf: url))
                guard kill(candidate.pid, 0) == 0 || errno == EPERM else {
                    try? FileManager.default.removeItem(at: url)
                    continue
                }
                endpoint = candidate
                return
            } catch {
                lastError = error
            }
        }
        if let lastError {
            throw XomoEndpointClientError.endpointInvalid(lastError.localizedDescription)
        }
        throw XomoEndpointClientError.endpointMissing(urls.map(\.path))
    }

    func status() throws -> Any {
        try request(operation: "status")
    }

    func tools() throws -> [[String: Any]] {
        let result = try request(operation: "tools")
        guard let tools = result as? [[String: Any]] else {
            throw XomoEndpointClientError.responseInvalid("tools result is not an array")
        }
        return tools
    }

    func call(name: String, arguments: [String: Any]) throws -> Any {
        try request(operation: "call", name: name, arguments: arguments)
    }

    private func request(
        operation: String,
        name: String? = nil,
        arguments: [String: Any]? = nil
    ) throws -> Any {
        var payload: [String: Any] = [
            "token": endpoint.token,
            "operation": operation
        ]
        if let name { payload["name"] = name }
        if let arguments { payload["arguments"] = arguments }
        var requestData = try JSONSerialization.data(withJSONObject: payload)
        requestData.append(0x0A)

        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            throw XomoEndpointClientError.connectionFailed(String(cString: strerror(errno)))
        }
        defer { close(socketFD) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = endpoint.port.bigEndian
        guard inet_pton(AF_INET, endpoint.host, &address.sin_addr) == 1 else {
            throw XomoEndpointClientError.endpointInvalid("unsupported host \(endpoint.host)")
        }

        let connectResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connectResult == 0 else {
            throw XomoEndpointClientError.connectionFailed(String(cString: strerror(errno)))
        }

        try writeAll(requestData, to: socketFD)
        let responseData = try readLine(from: socketFD)
        guard let response = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw XomoEndpointClientError.responseInvalid("root value is not an object")
        }
        guard response["ok"] as? Bool == true else {
            throw XomoEndpointClientError.requestFailed(response["error"] as? String ?? "unknown error")
        }
        return response["result"] ?? NSNull()
    }

    private func writeAll(_ data: Data, to socketFD: Int32) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            var offset = 0
            while offset < rawBuffer.count {
                let written = Darwin.write(socketFD, base.advanced(by: offset), rawBuffer.count - offset)
                guard written > 0 else {
                    throw XomoEndpointClientError.connectionFailed(String(cString: strerror(errno)))
                }
                offset += written
            }
        }
    }

    private func readLine(from socketFD: Int32) throws -> Data {
        var data = Data()
        var byte: UInt8 = 0
        while data.count < Self.maximumResponseBytes {
            let count = Darwin.read(socketFD, &byte, 1)
            if count == 0 { break }
            guard count > 0 else {
                throw XomoEndpointClientError.connectionFailed(String(cString: strerror(errno)))
            }
            if byte == 0x0A { break }
            data.append(byte)
        }
        guard data.count < Self.maximumResponseBytes else {
            throw XomoEndpointClientError.responseInvalid("response exceeds 256 MiB limit")
        }
        guard !data.isEmpty else {
            throw XomoEndpointClientError.responseInvalid("empty response")
        }
        return data
    }

    static var endpointURLs: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Library/Containers/im.some.xomo/Data/Library/Application Support/Xomo/automation-endpoint.json"),
            home.appendingPathComponent("Library/Application Support/Xomo/automation-endpoint.json")
        ]
    }
}
