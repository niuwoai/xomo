import Foundation
import Testing
@testable import XomoCLI

struct XomoMCPServerTests {
    @Test func initializeReturnsToolCapability() throws {
        let response = try #require(XomoMCPServer(version: "test").handle([
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": [:]
        ]))
        let result = try #require(response["result"] as? [String: Any])
        let capabilities = try #require(result["capabilities"] as? [String: Any])
        #expect(capabilities["tools"] != nil)
    }

    @Test func toolsListWorksWithoutRunningApp() throws {
        let response = try #require(XomoMCPServer(version: "test").handle([
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list",
            "params": [:]
        ]))
        let result = try #require(response["result"] as? [String: Any])
        let tools = try #require(result["tools"] as? [[String: Any]])
        #expect(tools.count == 106)
        #expect(tools.contains { $0["name"] as? String == "xomo.layer.list" })
        #expect(tools.contains { $0["name"] as? String == "xomo.channel.action" })
        #expect(tools.contains { $0["name"] as? String == "xomo.clipboard.action" })
        #expect(tools.contains { $0["name"] as? String == "xomo.path.action" })
        #expect(tools.contains { $0["name"] as? String == "xomo.layer_comp.action" })
        #expect(tools.contains { $0["name"] as? String == "xomo.text.convert" })
    }
}
