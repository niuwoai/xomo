import Foundation

struct XomoMCPServer {
    private let version: String
    private let toolsProvider: () throws -> [[String: Any]]

    init(
        version: String,
        toolsProvider: @escaping () throws -> [[String: Any]] = {
            try XomoEndpointClient().tools()
        }
    ) {
        self.version = version
        self.toolsProvider = toolsProvider
    }

    func run() {
        while let line = readLine(strippingNewline: true) {
            guard let data = line.data(using: .utf8),
                  let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                write(errorResponse(id: NSNull(), code: -32700, message: "Parse error"))
                continue
            }
            if let response = handle(request) {
                write(response)
            }
        }
    }

    func handle(_ request: [String: Any]) -> [String: Any]? {
        let method = request["method"] as? String ?? ""
        let id = request["id"] ?? NSNull()
        if request["id"] == nil {
            return nil
        }

        do {
            switch method {
            case "initialize":
                return successResponse(id: id, result: [
                    "protocolVersion": "2025-06-18",
                    "capabilities": ["tools": ["listChanged": false]],
                    "serverInfo": ["name": "xomo", "version": version]
                ])
            case "ping":
                return successResponse(id: id, result: [:])
            case "tools/list":
                let tools = (try? toolsProvider()) ?? XomoToolCatalog.fallbackTools
                return successResponse(id: id, result: ["tools": tools])
            case "tools/call":
                guard let params = request["params"] as? [String: Any],
                      let name = params["name"] as? String
                else { return errorResponse(id: id, code: -32602, message: "Missing tool name") }
                let arguments = params["arguments"] as? [String: Any] ?? [:]
                let result = try XomoEndpointClient().call(name: name, arguments: arguments)
                let text = prettyJSONString(result)
                return successResponse(id: id, result: [
                    "content": [["type": "text", "text": text]],
                    "structuredContent": result,
                    "isError": false
                ])
            default:
                return errorResponse(id: id, code: -32601, message: "Method not found: \(method)")
            }
        } catch {
            return successResponse(id: id, result: [
                "content": [["type": "text", "text": error.localizedDescription]],
                "isError": true
            ])
        }
    }

    private func successResponse(id: Any, result: Any) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "result": result]
    }

    private func errorResponse(id: Any, code: Int, message: String) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]]
    }

    private func write(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let line = String(data: data, encoding: .utf8)
        else { return }
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }
}

func prettyJSONString(_ object: Any) -> String {
    guard JSONSerialization.isValidJSONObject(object),
          let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
          let string = String(data: data, encoding: .utf8)
    else { return String(describing: object) }
    return string
}
