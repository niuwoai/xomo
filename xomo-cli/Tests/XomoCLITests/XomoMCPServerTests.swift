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
        let response = try #require(XomoMCPServer(
            version: "test",
            toolsProvider: { throw XomoEndpointClientError.endpointMissing([]) }
        ).handle([
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list",
            "params": [:]
        ]))
        let result = try #require(response["result"] as? [String: Any])
        let tools = try #require(result["tools"] as? [[String: Any]])
        #expect(tools.count == 122)
        #expect(tools.contains { $0["name"] as? String == "xomo.layer.list" })
        #expect(tools.contains { $0["name"] as? String == "xomo.figma.bindings" })
        #expect(tools.contains { $0["name"] as? String == "xomo.figma.component_properties" })
        #expect(tools.contains { $0["name"] as? String == "xomo.figma.link" })
        #expect(tools.contains { $0["name"] as? String == "xomo.component.instance" })
        #expect(tools.contains { $0["name"] as? String == "xomo.channel.action" })
        #expect(tools.contains { $0["name"] as? String == "xomo.clipboard.action" })
        let clipboardTool = try #require(tools.first { $0["name"] as? String == "xomo.clipboard.action" })
        let clipboardSchema = try #require(clipboardTool["inputSchema"] as? [String: Any])
        let clipboardProperties = try #require(clipboardSchema["properties"] as? [String: Any])
        let clipboardAction = try #require(clipboardProperties["action"] as? [String: Any])
        #expect(clipboardAction["enum"] as? [String] == [
            "pasteAsLayer",
            "pasteIntoSelection",
            "pasteInPlace",
            "copySelection",
            "cutSelection",
            "copyMerged",
            "copySelectedLayers"
        ])
        #expect(tools.contains { $0["name"] as? String == "xomo.path.action" })
        #expect(tools.contains { $0["name"] as? String == "xomo.layer_comp.action" })
        #expect(tools.contains { $0["name"] as? String == "xomo.layer.merge_selected" })
        #expect(tools.contains { $0["name"] as? String == "xomo.text.convert" })
        #expect(tools.contains { $0["name"] as? String == "xomo.text.fitBox" })
        #expect(tools.contains { $0["name"] as? String == "xomo.component.tokens" })
        #expect(tools.contains { $0["name"] as? String == "xomo.view.pan" })
        #expect(tools.contains { $0["name"] as? String == "xomo.selection.quick_mask" })
        #expect(tools.contains { $0["name"] as? String == "xomo.psd.inspect" })
        #expect(tools.contains { $0["name"] as? String == "xomo.psd.open" })
        #expect(tools.contains { $0["name"] as? String == "xomo.psd.save" })
    }
}
