import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoAutomationHotspotOrthogonalTransformTests {
    @Test
    func canvasTransformActionsShareHotspotBusinessEntry() throws {
        let expectations: [(String, CGSize, CGRect)] = [
            ("rotateClockwise", CGSize(width: 80, height: 100), CGRect(x: 55, y: 18, width: 10, height: 13)),
            ("rotateCounterclockwise", CGSize(width: 80, height: 100), CGRect(x: 15, y: 69, width: 10, height: 13)),
            ("rotate180", CGSize(width: 100, height: 80), CGRect(x: 69, y: 55, width: 13, height: 10)),
            ("flipHorizontal", CGSize(width: 100, height: 80), CGRect(x: 69, y: 15, width: 13, height: 10)),
            ("flipVertical", CGSize(width: 100, height: 80), CGRect(x: 18, y: 55, width: 13, height: 10))
        ]

        for (action, expectedCanvasSize, expectedFrame) in expectations {
            let viewModel = ImageEditorViewModel(
                sourceName: "automation-hotspot-orthogonal",
                image: NSImage.transparent(size: CGSize(width: 100, height: 80))
            ) { _ in }
            let hotspotID = UUID()
            viewModel.document.hotspots = [
                ImageEditorHotspot(
                    id: hotspotID,
                    name: "  Automation CTA  ",
                    frame: CGRect(x: 30.75, y: 24.25, width: -12.5, height: -8.5),
                    url: "  https://example.com/automation  "
                )
            ]

            try withRegistered(viewModel) { registry in
                let transformResponse = registry.execute(request(
                    name: "xomo.canvas.transform",
                    arguments: ["action": .string(action)]
                ))
                #expect(transformResponse.ok)
                #expect(viewModel.document.canvasSize == expectedCanvasSize)

                let listResponse = registry.execute(request(name: "xomo.hotspot.list"))
                #expect(listResponse.ok)
                let hotspots = try #require(listResponse.result?.arrayValue)
                let hotspot = try #require(hotspots.first?.objectValue)
                #expect(hotspots.count == 1)
                #expect(hotspot["id"] == .string(hotspotID.uuidString))
                #expect(hotspot["name"] == .string("  Automation CTA  "))
                #expect(hotspot["url"] == .string("  https://example.com/automation  "))
                #expect(hotspot["x"] == .number(Double(expectedFrame.minX)))
                #expect(hotspot["y"] == .number(Double(expectedFrame.minY)))
                #expect(hotspot["width"] == .number(Double(expectedFrame.width)))
                #expect(hotspot["height"] == .number(Double(expectedFrame.height)))
            }
        }
    }

    private func withRegistered(
        _ viewModel: ImageEditorViewModel,
        body: (XomoAutomationRegistry) throws -> Void
    ) rethrows {
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        try body(registry)
    }

    private func request(
        name: String,
        arguments: [String: XomoJSONValue]? = nil
    ) -> XomoAutomationWireRequest {
        XomoAutomationWireRequest(
            token: "test",
            operation: "call",
            name: name,
            arguments: arguments
        )
    }
}
