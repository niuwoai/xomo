import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorBevelShadowColorTransactionTests {
    @Test func bevelShadowColorConvergesMixedEditableSelectionInOneTransaction() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        let targetColor = NSColor(displayP3Red: 0.18, green: 0.34, blue: 0.72, alpha: 1)
        let normalizedTarget = try #require(targetColor.usingColorSpace(.sRGB))
        let targetProjectColor = ImageEditorProjectColor(color: normalizedTarget)

        first.style.bevelHighlightColor = .systemRed
        first.style.bevelShadowColor = .systemBlue
        first.style.bevelSize = 4
        first.style.bevelOpacity = 0.25
        first.style.bevelSoften = 2
        first.style.bevelDirection = .up
        second.style.bevelEnabled = true
        second.style.bevelHighlightColor = .systemGreen
        second.style.bevelShadowColor = normalizedTarget
        second.style.bevelSize = 12
        second.style.bevelOpacity = 0.75
        second.style.bevelSoften = 6
        second.style.bevelDirection = .down
        locked.style.bevelShadowColor = .systemOrange
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerBevelShadowColorState == .mixed)
        #expect(viewModel.setSelectedLayerBevelShadowColor(targetColor) == 1)
        #expect(viewModel.selectedLayerBevelShadowColorState == .value(targetProjectColor))
        #expect(viewModel.document.layers[0].style.bevelShadowColor.isEqual(normalizedTarget))
        #expect(viewModel.document.layers[1].style.bevelShadowColor.isEqual(normalizedTarget))
        #expect(viewModel.document.layers[2].style.bevelShadowColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[0].style.bevelHighlightColor.isEqual(NSColor.systemRed))
        #expect(viewModel.document.layers[1].style.bevelHighlightColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[0].style.bevelSize == 4)
        #expect(viewModel.document.layers[1].style.bevelSize == 12)
        #expect(viewModel.document.layers[0].style.bevelOpacity == 0.25)
        #expect(viewModel.document.layers[1].style.bevelOpacity == 0.75)
        #expect(viewModel.document.layers[0].style.bevelSoften == 2)
        #expect(viewModel.document.layers[1].style.bevelSoften == 6)
        #expect(viewModel.document.layers[0].style.bevelDirection == .up)
        #expect(viewModel.document.layers[1].style.bevelDirection == .down)
        #expect(viewModel.document.layers[0].style.bevelEnabled)
        #expect(viewModel.document.layers[1].style.bevelEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        #expect(viewModel.setSelectedLayerBevelShadowColor(targetColor) == 0)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        viewModel.undo()
        #expect(viewModel.selectedLayerBevelShadowColorState == .mixed)
        #expect(!viewModel.document.layers[0].style.bevelEnabled)
        #expect(viewModel.document.layers[0].style.bevelShadowColor.isEqual(NSColor.systemBlue))
        viewModel.redo()
        #expect(viewModel.selectedLayerBevelShadowColorState == .value(targetProjectColor))
        #expect(viewModel.document.layers[0].style.bevelEnabled)
        #expect(viewModel.document.layers[0].style.bevelShadowColor.isEqual(normalizedTarget))
    }

    @Test func bevelShadowColorControlReportsMixedValuesWithoutKeyboardFocus() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerBevelShadowColorState"))
        #expect(source.contains("selection: selectedLayerBevelShadowColorBinding"))
        #expect(source.contains("image-editor-layer-style-bevel-shadow-color"))
        #expect(source.contains("private func layerStyleColorPickerRow("))
        #expect(source.contains("state.isMixed"))
        #expect(source.contains("L10n.text(\"imageEditor.properties.multipleValues\")"))
        #expect(source.contains("ColorPicker(\"\", selection: selection, supportsOpacity: false)"))
        #expect(source.contains(".focusable(false)"))
    }

    @Test func automationReportsOnlyActuallyUpdatedBevelShadowColorLayers() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        let foreground = NSColor(srgbRed: 0.16, green: 0.28, blue: 0.68, alpha: 1)

        first.style.bevelHighlightColor = .systemRed
        first.style.bevelShadowColor = foreground
        first.style.bevelSize = 4
        second.style.bevelEnabled = true
        second.style.bevelHighlightColor = .systemGreen
        second.style.bevelShadowColor = foreground
        second.style.bevelSize = 12
        locked.style.bevelHighlightColor = .systemYellow
        locked.style.bevelShadowColor = .systemOrange
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        viewModel.foregroundColor = foreground
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
        #expect(propertyValues.contains(.string("bevelShadowColor")))

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("bevelShadowColor")]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.bevelEnabled)
        #expect(viewModel.document.layers[1].style.bevelEnabled)
        #expect(viewModel.document.layers[0].style.bevelShadowColor.isEqual(foreground))
        #expect(viewModel.document.layers[1].style.bevelShadowColor.isEqual(foreground))
        #expect(viewModel.document.layers[2].style.bevelShadowColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[0].style.bevelHighlightColor.isEqual(NSColor.systemRed))
        #expect(viewModel.document.layers[1].style.bevelHighlightColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[0].style.bevelSize == 4)
        #expect(viewModel.document.layers[1].style.bevelSize == 12)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("bevelShadowColor")]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let replacement = NSColor(srgbRed: 0.62, green: 0.2, blue: 0.4, alpha: 1)
        viewModel.foregroundColor = replacement
        let recolored = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("bevelShadowColor")]
        ))
        #expect(recolored.ok)
        #expect(recolored.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.bevelShadowColor.isEqual(replacement))
        #expect(viewModel.document.layers[1].style.bevelShadowColor.isEqual(replacement))
        #expect(viewModel.document.layers[2].style.bevelShadowColor.isEqual(NSColor.systemOrange))
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
            sourceName: "bevel-shadow-color-transaction",
            image: NSImage.transparent(size: CGSize(width: 320, height: 240))
        ) { _ in }
    }
}
