import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorBevelSizeTransactionTests {
    @Test func bevelSizeConvergesMixedEditableSelectionInOneTransaction() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.bevelSize = 4
        first.style.bevelOpacity = 0.25
        second.style.bevelEnabled = true
        second.style.bevelSize = 12
        second.style.bevelOpacity = 0.8
        locked.style.bevelSize = 20
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerBevelSizeState == .mixed)
        #expect(viewModel.setSelectedLayerBevelSize(12) == 1)
        #expect(viewModel.selectedLayerBevelSizeState == .value(12))
        #expect(viewModel.document.layers[0].style.bevelSize == 12)
        #expect(viewModel.document.layers[1].style.bevelSize == 12)
        #expect(viewModel.document.layers[2].style.bevelSize == 20)
        #expect(viewModel.document.layers[0].style.bevelOpacity == 0.25)
        #expect(viewModel.document.layers[1].style.bevelOpacity == 0.8)
        #expect(viewModel.document.layers[0].style.bevelEnabled)
        #expect(viewModel.document.layers[1].style.bevelEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        #expect(viewModel.setSelectedLayerBevelSize(12) == 0)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        viewModel.undo()
        #expect(viewModel.selectedLayerBevelSizeState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerBevelSizeState == .value(12))
    }

    @Test func bevelSizeControlUsesMixedNumericStepper() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerBevelSizeState"))
        #expect(source.contains("value: selectedLayerBevelSizeBinding"))
        #expect(source.contains("image-editor-layer-style-bevel-size"))
        #expect(source.contains("L10n.format(\"imageEditor.properties.bevelSizeValue\""))
    }

    @Test func automationReportsOnlyActuallyUpdatedBevelSizeLayers() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.bevelSize = 4
        second.style.bevelEnabled = true
        second.style.bevelSize = 12
        locked.style.bevelSize = 20
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
        #expect(propertyValues.contains(.string("bevelSize")))

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("bevelSize"),
                "value": .number(12)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.bevelSize == 12)
        #expect(viewModel.document.layers[1].style.bevelSize == 12)
        #expect(viewModel.document.layers[2].style.bevelSize == 20)
        #expect(viewModel.document.history.count == historyCount + 1)

        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("bevelSize"),
                "value": .number(12)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyCount + 1)

        let clamped = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("bevelSize"),
                "value": .number(100)
            ]
        ))
        #expect(clamped.ok)
        #expect(clamped.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.bevelSize == 24)
        #expect(viewModel.document.layers[1].style.bevelSize == 24)
        #expect(viewModel.document.layers[2].style.bevelSize == 20)
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
            sourceName: "bevel-size-transaction",
            image: NSImage.transparent(size: CGSize(width: 320, height: 240))
        ) { _ in }
    }
}
