import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorBevelOpacityTransactionTests {
    @Test func bevelOpacityConvergesMixedEditableSelectionInOneTransaction() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.bevelOpacity = 0.25
        first.style.bevelSize = 4
        second.style.bevelEnabled = true
        second.style.bevelOpacity = 0.75
        second.style.bevelSize = 12
        locked.style.bevelOpacity = 0.9
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerBevelOpacityState == .mixed)
        #expect(viewModel.setSelectedLayerBevelOpacity(0.75) == 1)
        #expect(viewModel.selectedLayerBevelOpacityState == .value(0.75))
        #expect(viewModel.document.layers[0].style.bevelOpacity == 0.75)
        #expect(viewModel.document.layers[1].style.bevelOpacity == 0.75)
        #expect(viewModel.document.layers[2].style.bevelOpacity == 0.9)
        #expect(viewModel.document.layers[0].style.bevelSize == 4)
        #expect(viewModel.document.layers[1].style.bevelSize == 12)
        #expect(viewModel.document.layers[0].style.bevelEnabled)
        #expect(viewModel.document.layers[1].style.bevelEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        #expect(viewModel.setSelectedLayerBevelOpacity(0.75) == 0)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        viewModel.undo()
        #expect(viewModel.selectedLayerBevelOpacityState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerBevelOpacityState == .value(0.75))
    }

    @Test func bevelOpacityControlUsesMixedNumericStepper() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerBevelOpacityState"))
        #expect(source.contains("value: selectedLayerBevelOpacityBinding"))
        #expect(source.contains("image-editor-layer-style-bevel-opacity"))
        #expect(source.contains("L10n.format(\"imageEditor.properties.bevelOpacityValue\""))
    }

    @Test func automationReportsOnlyActuallyUpdatedBevelOpacityLayers() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.bevelOpacity = 0.25
        second.style.bevelEnabled = true
        second.style.bevelOpacity = 0.75
        locked.style.bevelOpacity = 0.9
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
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
        #expect(propertyValues.contains(.string("bevelOpacity")))

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("bevelOpacity"),
                "value": .number(0.75)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.bevelOpacity == 0.75)
        #expect(viewModel.document.layers[1].style.bevelOpacity == 0.75)
        #expect(viewModel.document.layers[2].style.bevelOpacity == 0.9)
        #expect(viewModel.document.history.count == historyCount + 1)

        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("bevelOpacity"),
                "value": .number(0.75)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyCount + 1)

        let minimum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("bevelOpacity"),
                "value": .number(-1)
            ]
        ))
        #expect(minimum.ok)
        #expect(minimum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.bevelOpacity == 0.05)
        #expect(viewModel.document.layers[1].style.bevelOpacity == 0.05)
        #expect(viewModel.document.layers[2].style.bevelOpacity == 0.9)
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
            sourceName: "bevel-opacity-transaction",
            image: NSImage.transparent(size: CGSize(width: 320, height: 240))
        ) { _ in }
    }
}
