import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorSatinAutomationTransactionTests {
    @Test func satinAutomationReportsActualChangesForEveryAdvertisedProperty() throws {
        for property in SatinAutomationProperty.allCases {
            try assertTransaction(for: property)
        }
    }

    private func assertTransaction(
        for property: SatinAutomationProperty
    ) throws {
        let viewModel = makeViewModel()
        let canvasSize = viewModel.document.canvasSize
        var first = ImageEditorLayer.blank(name: "First", size: canvasSize)
        var second = ImageEditorLayer.blank(name: "Second", size: canvasSize)
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        property.configure(&first.style, matchesTarget: true)
        property.configure(&second.style, matchesTarget: false)
        property.configure(&locked.style, matchesTarget: false)
        locked.isLocked = true
        viewModel.foregroundColor = SatinAutomationProperty.targetColor
        viewModel.document.layers = [first, second, locked]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id]
        let historyCount = viewModel.document.history.count
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        let result = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: property.arguments
        ))

        #expect(result.ok, "Expected \(property.rawValue) to succeed")
        #expect(
            result.result?.objectValue?["updatedLayerCount"] == .number(1),
            "Expected only the mismatched editable layer to change for \(property.rawValue)"
        )
        #expect(property.matchesTarget(viewModel.document.layers[0].style))
        #expect(property.matchesTarget(viewModel.document.layers[1].style))
        #expect(!property.matchesTarget(viewModel.document.layers[2].style))
        #expect(viewModel.document.layers[0].style.satinEnabled)
        #expect(viewModel.document.layers[1].style.satinEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id, locked.id])

        let repeated = registry.execute(request(
            operation: "call",
            name: "xomo.layer.style_settings",
            arguments: property.arguments
        ))
        #expect(!repeated.ok, "Repeated \(property.rawValue) must report no-op")
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(property.matchesTarget(viewModel.document.layers[0].style))
        #expect(!property.matchesTarget(viewModel.document.layers[1].style))
        viewModel.redo()
        #expect(property.matchesTarget(viewModel.document.layers[0].style))
        #expect(property.matchesTarget(viewModel.document.layers[1].style))
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

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "satin-automation-transaction",
            image: NSImage.transparent(size: CGSize(width: 320, height: 240))
        ) { _ in }
    }
}

private enum SatinAutomationProperty: String, CaseIterable {
    case opacity = "satinOpacity"
    case color = "satinColor"
    case distance = "satinDistance"
    case size = "satinSize"
    case angle = "satinAngle"
    case invert = "satinInvert"
    case contour = "satinContour"

    static let targetColor = NSColor(
        srgbRed: 0.9,
        green: 0.15,
        blue: 0.2,
        alpha: 1
    )

    var arguments: [String: XomoJSONValue] {
        var result: [String: XomoJSONValue] = [
            "property": .string(rawValue)
        ]
        switch self {
        case .opacity:
            result["value"] = .number(0.6)
        case .color:
            break
        case .distance:
            result["value"] = .number(12)
        case .size:
            result["value"] = .number(8)
        case .angle:
            result["value"] = .number(45)
        case .invert:
            result["enabled"] = .bool(true)
        case .contour:
            result["satinContour"] = .string("ring")
        }
        return result
    }

    func configure(
        _ style: inout ImageEditorLayerStyle,
        matchesTarget: Bool
    ) {
        style.satinEnabled = true
        switch self {
        case .opacity:
            style.satinOpacity = matchesTarget ? 0.6 : 0.25
        case .color:
            style.satinColor = matchesTarget ? Self.targetColor : .systemGreen
        case .distance:
            style.satinDistance = matchesTarget ? 12 : 4
        case .size:
            style.satinSize = matchesTarget ? 8 : 3
        case .angle:
            style.satinAngle = matchesTarget ? 45 : -20
        case .invert:
            style.satinInvert = matchesTarget
        case .contour:
            style.satinContour = matchesTarget ? .ring : .linear
        }
    }

    func matchesTarget(_ style: ImageEditorLayerStyle) -> Bool {
        switch self {
        case .opacity:
            abs(style.satinOpacity - 0.6) < 0.001
        case .color:
            ImageEditorProjectColor(color: style.satinColor)
                == ImageEditorProjectColor(color: Self.targetColor)
        case .distance:
            abs(style.satinDistance - 12) < 0.001
        case .size:
            abs(style.satinSize - 8) < 0.001
        case .angle:
            abs(style.satinAngle - 45) < 0.001
        case .invert:
            style.satinInvert
        case .contour:
            style.satinContour == .ring
        }
    }
}
