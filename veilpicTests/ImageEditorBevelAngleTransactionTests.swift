import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorBevelAngleTransactionTests {
    @Test func bevelAngleConvergesGlobalAndLocalSelectionInOneTransaction() throws {
        let viewModel = makeViewModel()
        let fixture = configureFixture(in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerBevelAngleState == .mixed)
        #expect(viewModel.setSelectedLayerBevelAngle(-45) == 2)
        #expect(viewModel.selectedLayerBevelAngleState == .value(-45))
        #expect(viewModel.document.globalLightAngle == -45)
        #expect(viewModel.document.layers[0].style.bevelEnabled)
        #expect(viewModel.document.layers[1].style.bevelEnabled)
        #expect(viewModel.document.layers[0].style.resolvedBevelAngle(globalLightAngle: -45) == -45)
        #expect(viewModel.document.layers[1].style.resolvedBevelAngle(globalLightAngle: -45) == -45)
        #expect(viewModel.document.layers[2].style.bevelAngle == 90)
        #expect(viewModel.document.layers[0].style.bevelSize == 4)
        #expect(viewModel.document.layers[1].style.bevelSize == 12)
        #expect(viewModel.document.layers[0].style.bevelOpacity == 0.25)
        #expect(viewModel.document.layers[1].style.bevelOpacity == 0.75)
        #expect(viewModel.document.layers[0].style.bevelSoften == 2)
        #expect(viewModel.document.layers[1].style.bevelSoften == 8)
        #expect(viewModel.document.layers[0].style.bevelDirection == .up)
        #expect(viewModel.document.layers[1].style.bevelDirection == .down)
        #expect(viewModel.document.layers[0].style.bevelHighlightColor.isEqual(NSColor.systemRed))
        #expect(viewModel.document.layers[1].style.bevelHighlightColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[0].style.bevelShadowColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.layers[1].style.bevelShadowColor.isEqual(NSColor.systemPurple))
        #expect(viewModel.document.layers[3].style.resolvedShadowAngle(globalLightAngle: -45) == -45)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == fixture.selectedIDs)

        let historyAfterUpdate = viewModel.document.history.count
        #expect(viewModel.setSelectedLayerBevelAngle(315) == 0)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        viewModel.undo()
        #expect(viewModel.document.globalLightAngle == 35)
        #expect(viewModel.selectedLayerBevelAngleState == .mixed)
        #expect(!viewModel.document.layers[0].style.bevelEnabled)
        viewModel.redo()
        #expect(viewModel.document.globalLightAngle == -45)
        #expect(viewModel.selectedLayerBevelAngleState == .value(-45))
    }

    @Test func bevelAngleControlUsesMixedNumericStepper() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerBevelAngleState"))
        #expect(source.contains("value: selectedLayerBevelAngleBinding"))
        #expect(source.contains("range: -180...180"))
        #expect(source.contains("step: 15"))
        #expect(source.contains("image-editor-layer-style-bevel-angle"))
        #expect(source.contains("L10n.format(\"imageEditor.properties.bevelAngleValue\""))
    }

    @Test func automationReportsSelectedCountAndGlobalLightChangeForBevelAngle() throws {
        let viewModel = makeViewModel()
        let fixture = configureFixture(in: viewModel)
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let toolsResponse = registry.execute(request(operation: "tools"))
        let styleTool = try #require(automationTool(named: "xomo.layer.style_settings", in: toolsResponse))
        let properties = try #require(
            styleTool["inputSchema"]?.objectValue?["properties"]?.objectValue
        )
        let propertyValues = try #require(properties["property"]?.objectValue?["enum"]?.arrayValue)
        #expect(propertyValues.contains(.string("bevelAngle")))

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("bevelAngle"),
                "value": .number(-45)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(result.result?.objectValue?["globalLightUpdated"] == .bool(true))
        #expect(viewModel.document.globalLightAngle == -45)
        #expect(viewModel.document.layers[0].style.bevelEnabled)
        #expect(viewModel.document.layers[1].style.bevelEnabled)
        #expect(viewModel.document.layers[2].style.bevelAngle == 90)
        #expect(viewModel.document.layers[3].style.resolvedShadowAngle(globalLightAngle: -45) == -45)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == fixture.selectedIDs)

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("bevelAngle"),
                "value": .number(315)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        viewModel.setSelectedLayerBevelUsesGlobalLight(false)
        let local = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("bevelAngle"),
                "value": .number(20)
            ]
        ))
        #expect(local.ok)
        #expect(local.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(local.result?.objectValue?["globalLightUpdated"] == .bool(false))
        #expect(viewModel.document.globalLightAngle == -45)
        #expect(viewModel.document.layers[0].style.resolvedBevelAngle(globalLightAngle: -45) == 20)
        #expect(viewModel.document.layers[1].style.resolvedBevelAngle(globalLightAngle: -45) == 20)
    }

    private func configureFixture(
        in viewModel: ImageEditorViewModel
    ) -> (selectedIDs: Set<UUID>, firstID: UUID, secondID: UUID, lockedID: UUID) {
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        var linkedShadow = ImageEditorLayer.blank(name: "Linked Shadow", size: canvasSize)
        first.style.bevelUsesGlobalLight = true
        first.style.bevelAngle = 10
        first.style.bevelSize = 4
        first.style.bevelOpacity = 0.25
        first.style.bevelSoften = 2
        first.style.bevelDirection = .up
        first.style.bevelHighlightColor = .systemRed
        first.style.bevelShadowColor = .systemBlue
        second.style.bevelEnabled = true
        second.style.bevelUsesGlobalLight = false
        second.style.bevelAngle = -70
        second.style.bevelSize = 12
        second.style.bevelOpacity = 0.75
        second.style.bevelSoften = 8
        second.style.bevelDirection = .down
        second.style.bevelHighlightColor = .systemGreen
        second.style.bevelShadowColor = .systemPurple
        locked.style.bevelUsesGlobalLight = false
        locked.style.bevelAngle = 90
        locked.isLocked = true
        linkedShadow.style.shadowEnabled = true
        linkedShadow.style.shadowUsesGlobalLight = true
        linkedShadow.style.shadowAngle = 5
        viewModel.document.globalLightAngle = 35
        viewModel.document.layers = [first, second, locked, linkedShadow]
        viewModel.document.selectedLayerID = first.id
        let selectedIDs: Set<UUID> = [first.id, second.id, locked.id]
        viewModel.document.selectedLayerIDs = selectedIDs
        return (selectedIDs, first.id, second.id, locked.id)
    }

    private func request(
        operation: String,
        name: String? = nil,
        arguments: [String: XomoJSONValue]? = nil
    ) -> XomoAutomationWireRequest {
        XomoAutomationWireRequest(
            token: "test",
            operation: operation,
            name: name,
            arguments: arguments
        )
    }

    private func automationTool(
        named name: String,
        in response: XomoAutomationWireResponse
    ) -> [String: XomoJSONValue]? {
        guard case .array(let tools) = response.result else { return nil }
        return tools.compactMap { tool -> [String: XomoJSONValue]? in
            guard case .object(let value) = tool else { return nil }
            return value
        }.first { $0["name"] == .string(name) }
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "bevel-angle-transaction",
            image: NSImage.transparent(size: CGSize(width: 320, height: 240))
        ) { _ in }
    }
}
