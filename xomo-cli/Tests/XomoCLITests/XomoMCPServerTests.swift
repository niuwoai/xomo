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
        #expect(tools.count == 127)
        let layerListTool = try #require(tools.first { $0["name"] as? String == "xomo.layer.list" })
        let layerListSchema = try #require(layerListTool["inputSchema"] as? [String: Any])
        let layerListProperties = try #require(layerListSchema["properties"] as? [String: Any])
        let figmaConstraintFilter = try #require(layerListProperties["figmaConstraints"] as? [String: Any])
        #expect(figmaConstraintFilter["enum"] as? [String] == [
            "all", "constrained", "overridden", "conflicted"
        ])
        let figmaSourceFilter = try #require(layerListProperties["figmaSource"] as? [String: Any])
        #expect(figmaSourceFilter["enum"] as? [String] == ["all", "imported", "local"])
        let figmaNodeTypeFilter = try #require(layerListProperties["figmaNodeType"] as? [String: Any])
        #expect(figmaNodeTypeFilter["type"] as? String == "string")
        let figmaNodeIDFilter = try #require(layerListProperties["figmaNodeId"] as? [String: Any])
        #expect(figmaNodeIDFilter["type"] as? String == "string")
        let figmaFileKeyFilter = try #require(layerListProperties["figmaFileKey"] as? [String: Any])
        #expect(figmaFileKeyFilter["type"] as? String == "string")
        let figmaComponentRoleFilter = try #require(layerListProperties["figmaComponentRole"] as? [String: Any])
        #expect(figmaComponentRoleFilter["enum"] as? [String] == [
            "all", "none", "COMPONENT", "COMPONENT_SET", "INSTANCE"
        ])
        #expect(tools.contains { $0["name"] as? String == "xomo.layer.selection_bounds" })
        let transformReferenceTool = try #require(tools.first {
            $0["name"] as? String == "xomo.layer.transform_reference"
        })
        let transformReferenceSchema = try #require(
            transformReferenceTool["inputSchema"] as? [String: Any]
        )
        #expect(transformReferenceSchema["required"] as? [String] == ["action"])
        let transformReferenceProperties = try #require(
            transformReferenceSchema["properties"] as? [String: Any]
        )
        let transformReferenceAction = try #require(
            transformReferenceProperties["action"] as? [String: Any]
        )
        #expect(transformReferenceAction["enum"] as? [String] == ["set", "reset"])
        let objectSelectTool = try #require(tools.first { $0["name"] as? String == "xomo.object.select_at" })
        let objectSelectSchema = try #require(objectSelectTool["inputSchema"] as? [String: Any])
        #expect(objectSelectSchema["required"] as? [String] == ["x", "y"])
        let objectSelectProperties = try #require(objectSelectSchema["properties"] as? [String: Any])
        let objectSelectMode = try #require(objectSelectProperties["mode"] as? [String: Any])
        #expect(objectSelectMode["enum"] as? [String] == ["auto", "component", "deep"])
        #expect(tools.contains { $0["name"] as? String == "xomo.figma.bindings" })
        #expect(tools.contains { $0["name"] as? String == "xomo.figma.component_properties" })
        let sizeConstraintsTool = try #require(tools.first {
            $0["name"] as? String == "xomo.figma.size_constraints"
        })
        let sizeConstraintsSchema = try #require(
            sizeConstraintsTool["inputSchema"] as? [String: Any]
        )
        let sizeConstraintsProperties = try #require(
            sizeConstraintsSchema["properties"] as? [String: Any]
        )
        let sizeConstraintField = try #require(
            sizeConstraintsProperties["field"] as? [String: Any]
        )
        #expect(sizeConstraintField["enum"] as? [String] == [
            "minWidth", "maxWidth", "minHeight", "maxHeight"
        ])
        let sizeConstraintAction = try #require(
            sizeConstraintsProperties["action"] as? [String: Any]
        )
        #expect((sizeConstraintAction["enum"] as? [String])?.contains("resolve") == true)
        #expect((sizeConstraintAction["enum"] as? [String])?.contains("resolveAll") == true)
        let sizeConstraintAxis = try #require(
            sizeConstraintsProperties["axis"] as? [String: Any]
        )
        #expect(sizeConstraintAxis["enum"] as? [String] == ["width", "height"])
        #expect(tools.contains { $0["name"] as? String == "xomo.figma.image_fill" })
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
        let paintStrokeTool = try #require(
            tools.first { $0["name"] as? String == "xomo.paint.stroke" }
        )
        let paintStrokeSchema = try #require(
            paintStrokeTool["inputSchema"] as? [String: Any]
        )
        let paintStrokeProperties = try #require(
            paintStrokeSchema["properties"] as? [String: Any]
        )
        #expect(
            (paintStrokeProperties["tiltShape"] as? [String: Any])?["type"] as? String
                == "boolean"
        )
        #expect(
            (paintStrokeProperties["pressureOpacity"] as? [String: Any])?["type"] as? String
                == "boolean"
        )
        #expect(
            (paintStrokeProperties["minimumDiameter"] as? [String: Any])?["minimum"] as? Int == 0
        )
        #expect(
            (paintStrokeProperties["minimumDiameter"] as? [String: Any])?["maximum"] as? Int == 100
        )
        #expect(
            (paintStrokeProperties["minimumOpacity"] as? [String: Any])?["minimum"] as? Int == 0
        )
        #expect(
            (paintStrokeProperties["minimumOpacity"] as? [String: Any])?["maximum"] as? Int == 100
        )
        #expect(
            (paintStrokeProperties["minimumFlow"] as? [String: Any])?["minimum"] as? Int == 0
        )
        #expect(
            (paintStrokeProperties["minimumFlow"] as? [String: Any])?["maximum"] as? Int == 100
        )
        #expect(
            (paintStrokeProperties["roundness"] as? [String: Any])?["minimum"] as? Int == 10
        )
        #expect(
            (paintStrokeProperties["roundness"] as? [String: Any])?["maximum"] as? Int == 100
        )
        #expect(
            (paintStrokeProperties["angle"] as? [String: Any])?["minimum"] as? Int == -180
        )
        #expect(
            (paintStrokeProperties["angle"] as? [String: Any])?["maximum"] as? Int == 180
        )
        #expect(
            (paintStrokeProperties["smoothing"] as? [String: Any])?["minimum"] as? Int == 0
        )
        #expect(
            (paintStrokeProperties["smoothing"] as? [String: Any])?["maximum"] as? Int == 100
        )
        let paintPoints = try #require(
            paintStrokeProperties["points"] as? [String: Any]
        )
        let paintPointItems = try #require(paintPoints["items"] as? [String: Any])
        let paintPointProperties = try #require(
            paintPointItems["properties"] as? [String: Any]
        )
        #expect(
            (paintPointProperties["tiltX"] as? [String: Any])?["minimum"] as? Int == -1
        )
        #expect(
            (paintPointProperties["tiltY"] as? [String: Any])?["maximum"] as? Int == 1
        )
        let specialPaintTool = try #require(tools.first { $0["name"] as? String == "xomo.paint.special" })
        let specialPaintSchema = try #require(specialPaintTool["inputSchema"] as? [String: Any])
        let specialPaintProperties = try #require(specialPaintSchema["properties"] as? [String: Any])
        let toneRange = try #require(specialPaintProperties["toneRange"] as? [String: Any])
        #expect(toneRange["enum"] as? [String] == ["shadows", "midtones", "highlights"])
        let protectTones = try #require(specialPaintProperties["protectTones"] as? [String: Any])
        #expect(protectTones["type"] as? String == "boolean")
        let airbrush = try #require(specialPaintProperties["airbrush"] as? [String: Any])
        #expect(airbrush["type"] as? String == "boolean")
        let airbrushPulses = try #require(specialPaintProperties["airbrushPulses"] as? [String: Any])
        #expect(airbrushPulses["type"] as? String == "integer")
        #expect(airbrushPulses["minimum"] as? Int == 0)
        #expect(airbrushPulses["maximum"] as? Int == 80)
        let spongeVibrance = try #require(specialPaintProperties["spongeVibrance"] as? [String: Any])
        #expect(spongeVibrance["type"] as? String == "boolean")
        let fingerPainting = try #require(specialPaintProperties["fingerPainting"] as? [String: Any])
        #expect(fingerPainting["type"] as? String == "boolean")
        let sampleAllLayers = try #require(specialPaintProperties["sampleAllLayers"] as? [String: Any])
        #expect(sampleAllLayers["type"] as? String == "boolean")
        let spongeFlow = try #require(specialPaintProperties["flow"] as? [String: Any])
        #expect(spongeFlow["type"] as? String == "number")
        #expect(spongeFlow["minimum"] as? Int == 0)
        #expect(spongeFlow["maximum"] as? Int == 1)
        let retouchPressureSize = try #require(specialPaintProperties["pressureSize"] as? [String: Any])
        #expect(retouchPressureSize["type"] as? String == "boolean")
        #expect(
            retouchPressureSize["description"] as? String
                == "Use point pressure to control retouch brush diameter"
        )
        let retouchPressureSensitivity = try #require(
            specialPaintProperties["pressureSensitivity"] as? [String: Any]
        )
        #expect(retouchPressureSensitivity["type"] as? String == "number")
        #expect(retouchPressureSensitivity["minimum"] as? Int == 0)
        #expect(retouchPressureSensitivity["maximum"] as? Int == 100)
        #expect(tools.contains { $0["name"] as? String == "xomo.view.pan" })
        #expect(tools.contains { $0["name"] as? String == "xomo.selection.quick_mask" })
        #expect(tools.contains { $0["name"] as? String == "xomo.psd.inspect" })
        #expect(tools.contains { $0["name"] as? String == "xomo.psd.open" })
        #expect(tools.contains { $0["name"] as? String == "xomo.psd.save" })
    }
}
