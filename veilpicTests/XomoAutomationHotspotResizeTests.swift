import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoAutomationHotspotResizeTests {
    @Test func registryResizeImageScalesHotspotsReportedByHotspotList() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "automation-hotspot-resize",
            image: NSImage.transparent(size: CGSize(width: 320, height: 240))
        ) { _ in }
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let hotspotID = UUID()
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: hotspotID,
                name: "Responsive CTA",
                frame: CGRect(x: 24, y: 18, width: 60, height: 40),
                url: "https://example.com/responsive"
            )
        ]

        let resizeResponse = registry.execute(request(
            name: "xomo.canvas.resize_image",
            arguments: [
                "width": .number(160),
                "height": .number(480)
            ]
        ))
        #expect(resizeResponse.ok)

        let listResponse = registry.execute(request(name: "xomo.hotspot.list"))
        #expect(listResponse.ok)
        let listedHotspot = try #require(listResponse.result?.arrayValue?.first?.objectValue)
        #expect(listedHotspot["id"] == .string(hotspotID.uuidString))
        #expect(listedHotspot["name"] == .string("Responsive CTA"))
        #expect(listedHotspot["url"] == .string("https://example.com/responsive"))
        #expect(listedHotspot["x"] == .number(12))
        #expect(listedHotspot["y"] == .number(36))
        #expect(listedHotspot["width"] == .number(30))
        #expect(listedHotspot["height"] == .number(80))
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
