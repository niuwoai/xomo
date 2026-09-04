import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoAutomationHotspotCropRevealTests {
    @Test
    func cropToSelectionTransformsHotspotsReportedByHotspotList() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "automation-hotspot-crop-selection",
            image: NSImage.transparent(size: CGSize(width: 100, height: 80))
        ) { _ in }
        let hotspotID = UUID()
        viewModel.document.selection = .rectangle(CGRect(x: 20, y: 10, width: 50, height: 40))
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: hotspotID,
                name: "Selection CTA",
                frame: CGRect(x: 25, y: 15, width: 12, height: 10),
                url: "https://example.com/selection"
            )
        ]

        try withRegistered(viewModel) { registry in
            #expect(registry.execute(request(name: "xomo.canvas.crop_to_selection")).ok)
            try expectSingleHotspot(
                registry,
                id: hotspotID,
                name: "Selection CTA",
                url: "https://example.com/selection",
                frame: CGRect(x: 5, y: 5, width: 12, height: 10)
            )
        }
    }

    @Test
    func cropCenterTransformsHotspotsReportedByHotspotList() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "automation-hotspot-crop-center",
            image: NSImage.transparent(size: CGSize(width: 100, height: 80))
        ) { _ in }
        let hotspotID = UUID()
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: hotspotID,
                name: "Center CTA",
                frame: CGRect(x: 20, y: 20, width: 12, height: 10),
                url: "https://example.com/center"
            )
        ]

        try withRegistered(viewModel) { registry in
            #expect(registry.execute(request(
                name: "xomo.canvas.transform",
                arguments: ["action": .string("cropCenter")]
            )).ok)
            try expectSingleHotspot(
                registry,
                id: hotspotID,
                name: "Center CTA",
                url: "https://example.com/center",
                frame: CGRect(x: 12, y: 14, width: 12, height: 10)
            )
        }
    }

    @Test
    func trimTransparentTransformsHotspotsReportedByHotspotList() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "automation-hotspot-trim",
            image: NSImage.transparent(size: CGSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 30, y: 22, width: 20, height: 16)
        viewModel.document.layers[layerIndex].image = NSImage.opaqueMask(size: CGSize(width: 20, height: 16))
        let hotspotID = UUID()
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: hotspotID,
                name: "Trim CTA",
                frame: CGRect(x: 35, y: 27, width: 10, height: 8),
                url: "https://example.com/trim"
            )
        ]

        try withRegistered(viewModel) { registry in
            #expect(registry.execute(request(
                name: "xomo.canvas.transform",
                arguments: ["action": .string("trimTransparent")]
            )).ok)
            try expectSingleHotspot(
                registry,
                id: hotspotID,
                name: "Trim CTA",
                url: "https://example.com/trim",
                frame: CGRect(x: 5, y: 5, width: 10, height: 8)
            )
        }
    }

    @Test
    func revealAllTransformsHotspotsReportedByHotspotList() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "automation-hotspot-reveal",
            image: NSImage.transparent(size: CGSize(width: 100, height: 80))
        ) { _ in }
        var leftLayer = ImageEditorLayer.blank(
            name: "Visible Left",
            size: CGSize(width: 20, height: 16)
        )
        leftLayer.image = NSImage.opaqueMask(size: CGSize(width: 20, height: 16))
        leftLayer.frame = CGRect(x: -10, y: 12, width: 20, height: 16)
        viewModel.document.layers.append(leftLayer)
        let hotspotID = UUID()
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: hotspotID,
                name: "Reveal CTA",
                frame: CGRect(x: 10, y: 14, width: 12, height: 10),
                url: "https://example.com/reveal"
            )
        ]

        try withRegistered(viewModel) { registry in
            #expect(registry.execute(request(
                name: "xomo.canvas.transform",
                arguments: ["action": .string("revealAll")]
            )).ok)
            try expectSingleHotspot(
                registry,
                id: hotspotID,
                name: "Reveal CTA",
                url: "https://example.com/reveal",
                frame: CGRect(x: 20, y: 14, width: 12, height: 10)
            )
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

    private func expectSingleHotspot(
        _ registry: XomoAutomationRegistry,
        id: UUID,
        name: String,
        url: String,
        frame: CGRect
    ) throws {
        let listResponse = registry.execute(request(name: "xomo.hotspot.list"))
        #expect(listResponse.ok)
        let hotspots = try #require(listResponse.result?.arrayValue)
        #expect(hotspots.count == 1)
        let hotspot = try #require(hotspots.first?.objectValue)
        #expect(hotspot["id"] == .string(id.uuidString))
        #expect(hotspot["name"] == .string(name))
        #expect(hotspot["url"] == .string(url))
        #expect(hotspot["x"] == .number(Double(frame.minX)))
        #expect(hotspot["y"] == .number(Double(frame.minY)))
        #expect(hotspot["width"] == .number(Double(frame.width)))
        #expect(hotspot["height"] == .number(Double(frame.height)))
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
