import Darwin
import Foundation

private let xomoCLIVersion = "2.12.0-rc824"

struct XomoCLI {
    static func run(_ arguments: [String]) throws {
        let command = arguments.first ?? "help"
        switch command {
        case "help", "--help", "-h": printHelp()
        case "version", "--version": print(xomoCLIVersion)
        case "status": print(prettyJSONString(try XomoEndpointClient().status()))
        case "tools": print(prettyJSONString(try liveOrFallbackTools()))
        case "call": try call(arguments: Array(arguments.dropFirst()))
        case "export": try export(arguments: Array(arguments.dropFirst()))
        case "project": try project(arguments: Array(arguments.dropFirst()))
        case "import-image": try importImage(arguments: Array(arguments.dropFirst()))
        case "doctor": try doctor()
        case "mcp": XomoMCPServer(version: xomoCLIVersion).run()
        case "mcp-config": printMCPConfig()
        case "install": try install(arguments: Array(arguments.dropFirst()))
        default: throw CLIError.usage("Unknown command: \(command)")
        }
    }

    private static func call(arguments: [String]) throws {
        guard let name = arguments.first else { throw CLIError.usage("call requires a tool name") }
        let object = try parseJSONObject(arguments.dropFirst().first ?? "{}")
        print(prettyJSONString(try XomoEndpointClient().call(name: name, arguments: object)))
    }

    private static func export(arguments: [String]) throws {
        guard let destination = arguments.first else { throw CLIError.usage("export requires a destination path") }
        var options: [String: Any] = ["format": "png", "scope": "composited", "scale": 1.0]
        var index = 1
        while index < arguments.count {
            let flag = arguments[index]
            guard index + 1 < arguments.count else { throw CLIError.usage("Missing value for \(flag)") }
            let value = arguments[index + 1]
            switch flag {
            case "--format": options["format"] = value
            case "--scope": options["scope"] = value
            case "--scale": options["scale"] = Double(value) ?? 1
            case "--quality": options["quality"] = Double(value) ?? 0.9
            default: throw CLIError.usage("Unknown export option: \(flag)")
            }
            index += 2
        }
        guard let result = try XomoEndpointClient().call(name: "xomo.export.render", arguments: options) as? [String: Any],
              let base64 = result["base64"] as? String,
              let data = Data(base64Encoded: base64)
        else { throw CLIError.operation("Xomo returned invalid export data") }
        let url = URL(fileURLWithPath: NSString(string: destination).expandingTildeInPath)
        try data.write(to: url, options: .atomic)
        print(url.path)
    }

    private static func project(arguments: [String]) throws {
        guard arguments.count >= 2 else {
            throw CLIError.usage("project requires 'export <path>' or 'import <path>'")
        }
        let action = arguments[0]
        let url = expandedFileURL(arguments[1])
        switch action {
        case "export":
            guard let result = try XomoEndpointClient().call(
                name: "xomo.project.export",
                arguments: [:]
            ) as? [String: Any],
            let base64 = result["base64"] as? String,
            let data = Data(base64Encoded: base64)
            else { throw CLIError.operation("Xomo returned invalid project data") }
            try data.write(to: url, options: .atomic)
        case "import":
            let data = try Data(contentsOf: url)
            _ = try XomoEndpointClient().call(
                name: "xomo.project.import",
                arguments: ["base64": data.base64EncodedString()]
            )
        default: throw CLIError.usage("Unknown project action: \(action)")
        }
        print(url.path)
    }

    private static func importImage(arguments: [String]) throws {
        guard let path = arguments.first else { throw CLIError.usage("import-image requires a file path") }
        let url = expandedFileURL(path)
        let data = try Data(contentsOf: url)
        _ = try XomoEndpointClient().call(
            name: "xomo.import.image",
            arguments: [
                "base64": data.base64EncodedString(),
                "name": url.lastPathComponent,
                "intoSelection": arguments.dropFirst().contains("--into-selection")
            ]
        )
        print(url.path)
    }

    private static func expandedFileURL(_ path: String) -> URL {
        URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
    }

    private static func doctor() throws {
        let client = try XomoEndpointClient()
        print("xomo cli: \(xomoCLIVersion)")
        print("app endpoint: \(client.endpoint.host):\(client.endpoint.port)")
        print("app pid: \(client.endpoint.pid)")
        print("app version: \(client.endpoint.version)")
        _ = try client.status()
        print("connection: ok")
        print("tools: \(try client.tools().count)")
    }

    private static func install(arguments: [String]) throws {
        let prefix = arguments.first ?? "~/.local"
        let expandedPrefix = NSString(string: prefix).expandingTildeInPath
        let binDirectory = URL(fileURLWithPath: expandedPrefix).appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: binDirectory, withIntermediateDirectories: true)
        let source = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let destination = binDirectory.appendingPathComponent("xomo")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
        print(destination.path)
    }

    private static func printMCPConfig() {
        let executable = NSString(string: "~/.local/bin/xomo").expandingTildeInPath
        print(prettyJSONString([
            "mcpServers": [
                "xomo": ["command": executable, "args": ["mcp"]]
            ]
        ]))
    }

    private static func liveOrFallbackTools() throws -> [[String: Any]] {
        (try? XomoEndpointClient().tools()) ?? XomoToolCatalog.fallbackTools
    }

    private static func parseJSONObject(_ json: String) throws -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw CLIError.usage("Arguments must be a JSON object") }
        return object
    }

    private static func printHelp() {
        print("""
        Xomo CLI \(xomoCLIVersion)

        Usage:
          xomo status
          xomo tools
          xomo call <tool-name> '<json-arguments>'
          xomo export <path> [--format png] [--scope composited] [--scale 1]
          xomo project export <path.qpicproject>
          xomo project import <path.qpicproject>
          xomo import-image <path> [--into-selection]
          xomo doctor
          xomo mcp
          xomo mcp-config
          xomo install [prefix]
          xomo version
        """)
    }
}

private enum CLIError: LocalizedError {
    case usage(String)
    case operation(String)

    var errorDescription: String? {
        switch self {
        case .usage(let message), .operation(let message): message
        }
    }
}

do {
    try XomoCLI.run(Array(CommandLine.arguments.dropFirst()))
} catch {
    FileHandle.standardError.write(Data(("xomo: \(error.localizedDescription)\n").utf8))
    exit(1)
}
