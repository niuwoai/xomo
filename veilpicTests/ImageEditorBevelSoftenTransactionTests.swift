import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorBevelSoftenTransactionTests {
    @Test func bevelSoftenConvergesMixedEditableSelectionInOneTransaction() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.bevelSoften = 2
        first.style.bevelSize = 4
        first.style.bevelOpacity = 0.25
        first.style.bevelHighlightColor = .systemRed
        first.style.bevelShadowColor = .systemBlue
        first.style.bevelDirection = .up
        second.style.bevelEnabled = true
        second.style.bevelSoften = 8
        second.style.bevelSize = 12
        second.style.bevelOpacity = 0.75
        second.style.bevelHighlightColor = .systemGreen
        second.style.bevelShadowColor = .systemPurple
        second.style.bevelDirection = .down
        locked.style.bevelSoften = 12
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerBevelSoftenState == .mixed)
        #expect(viewModel.setSelectedLayerBevelSoften(8) == 1)
        #expect(viewModel.selectedLayerBevelSoftenState == .value(8))
        #expect(viewModel.document.layers[0].style.bevelSoften == 8)
        #expect(viewModel.document.layers[1].style.bevelSoften == 8)
        #expect(viewModel.document.layers[2].style.bevelSoften == 12)
        #expect(viewModel.document.layers[0].style.bevelSize == 4)
        #expect(viewModel.document.layers[1].style.bevelSize == 12)
        #expect(viewModel.document.layers[0].style.bevelOpacity == 0.25)
        #expect(viewModel.document.layers[1].style.bevelOpacity == 0.75)
        #expect(viewModel.document.layers[0].style.bevelHighlightColor.isEqual(NSColor.systemRed))
        #expect(viewModel.document.layers[1].style.bevelHighlightColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[0].style.bevelShadowColor.isEqual(NSColor.systemBlue))
        #expect(viewModel.document.layers[1].style.bevelShadowColor.isEqual(NSColor.systemPurple))
        #expect(viewModel.document.layers[0].style.bevelDirection == .up)
        #expect(viewModel.document.layers[1].style.bevelDirection == .down)
        #expect(viewModel.document.layers[0].style.bevelEnabled)
        #expect(viewModel.document.layers[1].style.bevelEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        #expect(viewModel.setSelectedLayerBevelSoften(8) == 0)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        viewModel.undo()
        #expect(viewModel.selectedLayerBevelSoftenState == .mixed)
        #expect(!viewModel.document.layers[0].style.bevelEnabled)
        viewModel.redo()
        #expect(viewModel.selectedLayerBevelSoftenState == .value(8))
        #expect(viewModel.document.layers[0].style.bevelEnabled)
    }

    @Test func bevelSoftenControlUsesMixedNumericStepper() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerBevelSoftenState"))
        #expect(source.contains("value: selectedLayerBevelSoftenBinding"))
        #expect(source.contains("range: 0...24"))
        #expect(source.contains("image-editor-layer-style-bevel-soften"))
        #expect(source.contains("L10n.format(\"imageEditor.properties.bevelSoftenValue\""))
    }

    @Test func automationReportsOnlyActuallyUpdatedBevelSoftenLayers() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        first.style.bevelSoften = 8
        first.style.bevelHighlightColor = .systemRed
        second.style.bevelEnabled = true
        second.style.bevelSoften = 8
        second.style.bevelHighlightColor = .systemGreen
        locked.style.bevelSoften = 12
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
        #expect(propertyValues.contains(.string("bevelSoften")))

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("bevelSoften"),
                "value": .number(8)
            ]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.bevelEnabled)
        #expect(viewModel.document.layers[1].style.bevelEnabled)
        #expect(viewModel.document.layers[0].style.bevelSoften == 8)
        #expect(viewModel.document.layers[1].style.bevelSoften == 8)
        #expect(viewModel.document.layers[2].style.bevelSoften == 12)
        #expect(viewModel.document.layers[0].style.bevelHighlightColor.isEqual(NSColor.systemRed))
        #expect(viewModel.document.layers[1].style.bevelHighlightColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("bevelSoften"),
                "value": .number(8)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let maximum = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string("bevelSoften"),
                "value": .number(99)
            ]
        ))
        #expect(maximum.ok)
        #expect(maximum.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.bevelSoften == 24)
        #expect(viewModel.document.layers[1].style.bevelSoften == 24)
        #expect(viewModel.document.layers[2].style.bevelSoften == 12)
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
            sourceName: "bevel-soften-transaction",
            image: NSImage.transparent(size: CGSize(width: 320, height: 240))
        ) { _ in }
    }
}
