import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorGlobalLightLinkAutomationTests {
    @Test func automationExposesAllPerEffectGlobalLightLinkages() throws {
        let viewModel = makeViewModel()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let toolsResponse = registry.execute(request(operation: "tools"))
        let styleTool = try #require(
            automationTool(named: "xomo.layer.style_settings", in: toolsResponse)
        )
        let properties = try #require(
            styleTool["inputSchema"]?.objectValue?["properties"]?.objectValue
        )
        let propertyValues = try #require(
            properties["property"]?.objectValue?["enum"]?.arrayValue
        )

        #expect(propertyValues.contains(.string("shadowUsesGlobalLight")))
        #expect(propertyValues.contains(.string("innerShadowUsesGlobalLight")))
        #expect(propertyValues.contains(.string("bevelUsesGlobalLight")))
        #expect(properties["enabled"]?.objectValue?["type"] == .string("boolean"))
    }

    @Test func automationConvergesGlobalLightLinkagesAndReportsActualChanges() throws {
        try assertGlobalLightLinkage(
            property: "shadowUsesGlobalLight",
            effect: .shadow
        )
        try assertGlobalLightLinkage(
            property: "innerShadowUsesGlobalLight",
            effect: .innerShadow
        )
        try assertGlobalLightLinkage(
            property: "bevelUsesGlobalLight",
            effect: .bevel
        )
    }

    private func assertGlobalLightLinkage(
        property: String,
        effect: ImageEditorLayerLightEffect
    ) throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        viewModel.document.globalLightAngle = 30
        configure(
            &first.style,
            effect: effect,
            enabled: true,
            usesGlobalLight: true,
            angle: 30
        )
        configure(
            &second.style,
            effect: effect,
            enabled: true,
            usesGlobalLight: false,
            angle: 75
        )
        configure(
            &locked.style,
            effect: effect,
            enabled: true,
            usesGlobalLight: false,
            angle: -20
        )
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let enabled = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string(property),
                "enabled": .bool(true)
            ]
        ))

        #expect(enabled.ok)
        #expect(enabled.result?.objectValue?["updatedLayerCount"] == .number(1))
        #expect(effect.usesGlobalLight(in: viewModel.document.layers[0].style))
        #expect(effect.usesGlobalLight(in: viewModel.document.layers[1].style))
        #expect(!effect.usesGlobalLight(in: viewModel.document.layers[2].style))
        #expect(resolvedAngle(viewModel.document.layers[1].style, effect: effect) == 30)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string(property),
                "enabled": .bool(true)
            ]
        ))
        #expect(!repeated.ok)
        #expect(viewModel.document.history.count == historyCount + 1)

        let disabled = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: [
                "property": .string(property),
                "enabled": .bool(false)
            ]
        ))
        #expect(disabled.ok)
        #expect(disabled.result?.objectValue?["updatedLayerCount"] == .number(2))
        #expect(!effect.usesGlobalLight(in: viewModel.document.layers[0].style))
        #expect(!effect.usesGlobalLight(in: viewModel.document.layers[1].style))
        #expect(!effect.usesGlobalLight(in: viewModel.document.layers[2].style))
        #expect(resolvedAngle(viewModel.document.layers[0].style, effect: effect) == 30)
        #expect(resolvedAngle(viewModel.document.layers[1].style, effect: effect) == 30)
        #expect(viewModel.document.history.count == historyCount + 2)

        viewModel.undo()
        #expect(effect.usesGlobalLight(in: viewModel.document.layers[0].style))
        #expect(effect.usesGlobalLight(in: viewModel.document.layers[1].style))
        viewModel.redo()
        #expect(!effect.usesGlobalLight(in: viewModel.document.layers[0].style))
        #expect(!effect.usesGlobalLight(in: viewModel.document.layers[1].style))
    }

    private func configure(
        _ style: inout ImageEditorLayerStyle,
        effect: ImageEditorLayerLightEffect,
        enabled: Bool,
        usesGlobalLight: Bool,
        angle: CGFloat
    ) {
        switch effect {
        case .shadow:
            style.shadowEnabled = enabled
            style.shadowUsesGlobalLight = usesGlobalLight
            style.shadowAngle = angle
            style.shadowOffset = ImageEditorLayerStyle.shadowOffset(
                distance: style.shadowDistance,
                angle: angle
            )
        case .innerShadow:
            style.innerShadowEnabled = enabled
            style.innerShadowUsesGlobalLight = usesGlobalLight
            style.innerShadowAngle = angle
        case .bevel:
            style.bevelEnabled = enabled
            style.bevelUsesGlobalLight = usesGlobalLight
            style.bevelAngle = angle
        }
    }

    private func resolvedAngle(
        _ style: ImageEditorLayerStyle,
        effect: ImageEditorLayerLightEffect
    ) -> CGFloat {
        switch effect {
        case .shadow: style.resolvedShadowAngle(globalLightAngle: 30)
        case .innerShadow: style.resolvedInnerShadowAngle(globalLightAngle: 30)
        case .bevel: style.resolvedBevelAngle(globalLightAngle: 30)
        }
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
            sourceName: "global-light-link-automation",
            image: NSImage.transparent(size: CGSize(width: 320, height: 240))
        ) { _ in }
    }
}
