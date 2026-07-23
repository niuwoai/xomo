import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorBevelHighlightColorTransactionTests {
    @Test func bevelHighlightColorConvergesMixedEditableSelectionInOneTransaction() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        let targetColor = NSColor(displayP3Red: 0.78, green: 0.24, blue: 0.54, alpha: 1)
        let normalizedTarget = try #require(targetColor.usingColorSpace(.sRGB))
        let targetProjectColor = ImageEditorProjectColor(color: normalizedTarget)

        first.style.bevelHighlightColor = .systemBlue
        first.style.bevelShadowColor = .systemRed
        first.style.bevelSize = 4
        first.style.bevelOpacity = 0.25
        first.style.bevelSoften = 2
        first.style.bevelDirection = .up
        second.style.bevelEnabled = true
        second.style.bevelHighlightColor = normalizedTarget
        second.style.bevelShadowColor = .systemGreen
        second.style.bevelSize = 12
        second.style.bevelOpacity = 0.75
        second.style.bevelSoften = 6
        second.style.bevelDirection = .down
        locked.style.bevelHighlightColor = .systemOrange
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerBevelHighlightColorState == .mixed)
        #expect(viewModel.setSelectedLayerBevelHighlightColor(targetColor) == 1)
        #expect(viewModel.selectedLayerBevelHighlightColorState == .value(targetProjectColor))
        #expect(viewModel.document.layers[0].style.bevelHighlightColor.isEqual(normalizedTarget))
        #expect(viewModel.document.layers[1].style.bevelHighlightColor.isEqual(normalizedTarget))
        #expect(viewModel.document.layers[2].style.bevelHighlightColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[0].style.bevelShadowColor.isEqual(NSColor.systemRed))
        #expect(viewModel.document.layers[1].style.bevelShadowColor.isEqual(NSColor.systemGreen))
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
        #expect(viewModel.setSelectedLayerBevelHighlightColor(targetColor) == 0)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        viewModel.undo()
        #expect(viewModel.selectedLayerBevelHighlightColorState == .mixed)
        #expect(!viewModel.document.layers[0].style.bevelEnabled)
        #expect(viewModel.document.layers[0].style.bevelHighlightColor.isEqual(NSColor.systemBlue))
        viewModel.redo()
        #expect(viewModel.selectedLayerBevelHighlightColorState == .value(targetProjectColor))
        #expect(viewModel.document.layers[0].style.bevelEnabled)
        #expect(viewModel.document.layers[0].style.bevelHighlightColor.isEqual(normalizedTarget))
    }

    @Test func bevelHighlightColorControlReportsMixedValuesWithoutKeyboardFocus() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerBevelHighlightColorState"))
        #expect(source.contains("selection: selectedLayerBevelHighlightColorBinding"))
        #expect(source.contains("image-editor-layer-style-bevel-highlight-color"))
        #expect(source.contains("private func layerStyleColorPickerRow("))
        #expect(source.contains("state.isMixed"))
        #expect(source.contains("L10n.text(\"imageEditor.properties.multipleValues\")"))
        #expect(source.contains("ColorPicker(\"\", selection: selection, supportsOpacity: false)"))
        #expect(source.contains(".focusable(false)"))
    }

    @Test func automationReportsOnlyActuallyUpdatedBevelHighlightColorLayers() throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        let foreground = NSColor(srgbRed: 0.72, green: 0.18, blue: 0.46, alpha: 1)

        first.style.bevelHighlightColor = foreground
        first.style.bevelShadowColor = .systemRed
        first.style.bevelSize = 4
        second.style.bevelEnabled = true
        second.style.bevelHighlightColor = foreground
        second.style.bevelShadowColor = .systemGreen
        second.style.bevelSize = 12
        locked.style.bevelHighlightColor = .systemOrange
        locked.style.bevelShadowColor = .systemPurple
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
        #expect(propertyValues.contains(.string("bevelHighlightColor")))

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("bevelHighlightColor")]
        ))

        #expect(result.ok)
        #expect(result.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(viewModel.document.layers[0].style.bevelEnabled)
        #expect(viewModel.document.layers[1].style.bevelEnabled)
        #expect(viewModel.document.layers[0].style.bevelHighlightColor.isEqual(foreground))
        #expect(viewModel.document.layers[1].style.bevelHighlightColor.isEqual(foreground))
        #expect(viewModel.document.layers[2].style.bevelHighlightColor.isEqual(NSColor.systemOrange))
        #expect(viewModel.document.layers[0].style.bevelShadowColor.isEqual(NSColor.systemRed))
        #expect(viewModel.document.layers[1].style.bevelShadowColor.isEqual(NSColor.systemGreen))
        #expect(viewModel.document.layers[0].style.bevelSize == 4)
        #expect(viewModel.document.layers[1].style.bevelSize == 12)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let historyAfterUpdate = viewModel.document.history.count
        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("bevelHighlightColor")]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyAfterUpdate)

        let replacement = NSColor(srgbRed: 0.16, green: 0.74, blue: 0.38, alpha: 1)
        viewModel.foregroundColor = replacement
        let recolored = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: ["property": .string("bevelHighlightColor")]
        ))
        #expect(recolored.ok)
        #expect(recolored.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(viewModel.document.layers[0].style.bevelHighlightColor.isEqual(replacement))
        #expect(viewModel.document.layers[1].style.bevelHighlightColor.isEqual(replacement))
        #expect(viewModel.document.layers[2].style.bevelHighlightColor.isEqual(NSColor.systemOrange))
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
            sourceName: "bevel-highlight-color-transaction",
            image: NSImage.transparent(size: CGSize(width: 320, height: 240))
        ) { _ in }
    }
}
