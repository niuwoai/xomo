//
//  XomoAutomationServer.swift
//  veilpic
//

import Foundation
import Network

@MainActor
final class XomoAutomationServer {
    static let shared = XomoAutomationServer()
    nonisolated private static let maximumRequestBytes = 128 * 1024 * 1024
    nonisolated private static let receiveChunkBytes = 1024 * 1024

    private let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    private let networkQueue = DispatchQueue(label: "im.some.xomo.automation", qos: .userInitiated)
    private var listener: NWListener?

    private init() {}

    func start() {
        guard listener == nil else { return }
        try? FileManager.default.removeItem(at: Self.endpointFileURL)
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
            let listener = try NWListener(using: parameters)
            self.listener = listener
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in self?.handleListenerState(state) }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in self?.accept(connection) }
            }
            listener.start(queue: networkQueue)
        } catch {
            listener = nil
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        try? FileManager.default.removeItem(at: Self.endpointFileURL)
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            guard let port = listener?.port?.rawValue else { return }
            publishEndpoint(port: port)
        case .failed, .cancelled:
            listener = nil
            try? FileManager.default.removeItem(at: Self.endpointFileURL)
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        guard isLoopback(connection.endpoint) else {
            connection.cancel()
            return
        }
        connection.start(queue: networkQueue)
        receive(from: connection, accumulated: Data())
    }

    private func receive(from connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.receiveChunkBytes) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            var buffer = accumulated
            if let data { buffer.append(data) }
            if let newline = buffer.firstIndex(of: 0x0A) {
                let requestData = buffer[..<newline]
                Task { @MainActor in
                    let response = self.response(for: Data(requestData))
                    self.send(response, to: connection)
                }
                return
            }
            if error != nil || isComplete || buffer.count >= Self.maximumRequestBytes {
                connection.cancel()
                return
            }
            let nextBuffer = buffer
            Task { @MainActor [weak self, nextBuffer] in
                self?.receive(from: connection, accumulated: nextBuffer)
            }
        }
    }

    private func response(for data: Data) -> XomoAutomationWireResponse {
        do {
            let request = try JSONDecoder().decode(XomoAutomationWireRequest.self, from: data)
            guard request.token == token else { return .failure("Authentication failed") }
            return XomoAutomationRegistry.shared.execute(request)
        } catch {
            return .failure("Invalid automation request: \(error.localizedDescription)")
        }
    }

    private func send(_ response: XomoAutomationWireResponse, to connection: NWConnection) {
        do {
            var data = try JSONEncoder().encode(response)
            data.append(0x0A)
            connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
        } catch {
            connection.cancel()
        }
    }

    private func publishEndpoint(port: UInt16) {
        do {
            let directory = Self.endpointFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let endpoint = XomoAutomationEndpoint(
                host: "127.0.0.1",
                port: port,
                token: token,
                pid: ProcessInfo.processInfo.processIdentifier,
                version: AppVersion.current
            )
            let data = try JSONEncoder().encode(endpoint)
            try data.write(to: Self.endpointFileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: Self.endpointFileURL.path
            )
        } catch {
            // The editor remains usable even if automation endpoint publication fails.
        }
    }

    private func isLoopback(_ endpoint: NWEndpoint) -> Bool {
        guard case .hostPort(let host, _) = endpoint else { return false }
        let value = String(describing: host)
        return value == "127.0.0.1" || value == "::1" || value == "localhost"
    }

    static var endpointFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Xomo", isDirectory: true)
            .appendingPathComponent("automation-endpoint.json")
    }
}
