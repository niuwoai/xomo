import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoAutomationHotspotCanvasResizeTests {
    @Test func registryResizeCanvasOffsetsAndClipsHotspotsReportedByHotspotList() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "automation-hotspot-canvas-resize",
            image: NSImage.transparent(size: CGSize(width: 100, height: 80))
        ) { _ in }
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let keptID = UUID()
        let removedID = UUID()
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: keptID,
                name: "Canvas CTA",
                frame: CGRect(x: 10, y: 10, width: 30, height: 20),
                url: "https://example.com/canvas"
            ),
            ImageEditorHotspot(
                id: removedID,
                name: "Outside CTA",
                frame: CGRect(x: 80, y: 20, width: 10, height: 10),
                url: "https://example.com/outside"
            )
        ]

        let resizeResponse = registry.execute(request(
            name: "xomo.canvas.resize_canvas",
            arguments: [
                "width": .number(60),
                "height": .number(40),
                "anchor": .string(ImageEditorCanvasAnchor.center.rawValue)
            ]
        ))
        #expect(resizeResponse.ok)

        let listResponse = registry.execute(request(name: "xomo.hotspot.list"))
        #expect(listResponse.ok)
        let hotspots = try #require(listResponse.result?.arrayValue)
        #expect(hotspots.count == 1)
        let hotspot = try #require(hotspots.first?.objectValue)
        #expect(hotspot["id"] == .string(keptID.uuidString))
        #expect(hotspot["name"] == .string("Canvas CTA"))
        #expect(hotspot["url"] == .string("https://example.com/canvas"))
        #expect(hotspot["x"] == .number(0))
        #expect(hotspot["y"] == .number(0))
        #expect(hotspot["width"] == .number(20))
        #expect(hotspot["height"] == .number(10))
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
