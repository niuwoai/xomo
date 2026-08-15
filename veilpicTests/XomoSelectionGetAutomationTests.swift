import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct XomoSelectionGetAutomationTests {
    private let canvasSize = CGSize(width: 80, height: 60)

    @Test func selectionGetReportsOnlyEffectiveSelectedPixels() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "selection-get",
            image: .transparent(size: canvasSize)
        ) { _ in }
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }

        #expect(try selectionResult(from: registry) == ["active": .bool(false)])

        viewModel.document.selection = .rectangle(
            CGRect(x: -5, y: -4, width: 20, height: 14)
        )
        #expect(try selectionResult(from: registry) == expectedActiveBounds(
            CGRect(x: 0, y: 0, width: 15, height: 10),
            inverted: false
        ))

        let selectedFrame = CGRect(x: 13, y: 9, width: 17, height: 11)
        let mask = rectangularMask(selectedFrame)
        viewModel.document.selection = .raster(
            mask: mask,
            bounds: CGRect(origin: .zero, size: canvasSize)
        )
        #expect(try selectionResult(from: registry) == expectedActiveBounds(
            selectedFrame,
            inverted: false
        ))

        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(
                width: Int(canvasSize.width),
                height: Int(canvasSize.height),
                alpha: [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
            ),
            bounds: CGRect(origin: .zero, size: canvasSize)
        )
        #expect(try selectionResult(from: registry) == ["active": .bool(false)])

        var inverted = ImageEditorSelection.raster(
            mask: mask,
            bounds: CGRect(origin: .zero, size: canvasSize)
        )
        inverted.isInverted = true
        viewModel.document.selection = inverted
        #expect(try selectionResult(from: registry) == expectedActiveBounds(
            CGRect(origin: .zero, size: canvasSize),
            inverted: true
        ))
    }

    private func selectionResult(
        from registry: XomoAutomationRegistry
    ) throws -> [String: XomoJSONValue] {
        let response = registry.execute(XomoAutomationWireRequest(
            token: "test",
            operation: "call",
            name: "xomo.selection.get",
            arguments: nil
        ))
        #expect(response.ok)
        return try #require(response.result?.objectValue)
    }

    private func expectedActiveBounds(
        _ bounds: CGRect,
        inverted: Bool
    ) -> [String: XomoJSONValue] {
        [
            "active": .bool(true),
            "inverted": .bool(inverted),
            "x": .number(bounds.minX),
            "y": .number(bounds.minY),
            "width": .number(bounds.width),
            "height": .number(bounds.height)
        ]
    }

    private func rectangularMask(_ rect: CGRect) -> ImageEditorSelectionMask {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) {
                alpha[y * width + x] = UInt8.max
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }
}
