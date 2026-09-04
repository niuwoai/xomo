import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoAutomationSliceRevealAllTests {
    @Test func registryRevealAllOffsetsSliceListAndPreservesExportPlan() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "automation-slice-reveal",
            image: NSImage.transparent(size: CGSize(width: 100, height: 80))
        ) { _ in }
        var leftLayer = ImageEditorLayer.blank(
            name: "Visible left",
            size: CGSize(width: 20, height: 16)
        )
        leftLayer.image = NSImage.opaqueMask(size: CGSize(width: 20, height: 16))
        leftLayer.frame = CGRect(x: -10, y: 12, width: 20, height: 16)
        viewModel.document.layers.append(leftLayer)
        let sliceID = UUID()
        let presets = [
            ImageEditorSliceExportPreset(suffix: "-width", format: .png, constraint: .width, value: 40),
            ImageEditorSliceExportPreset(suffix: "-height", format: .jpeg, constraint: .height, value: 20),
            ImageEditorSliceExportPreset(suffix: "-vector", format: .pdf, constraint: .scale, value: 1)
        ]
        viewModel.document.slices = [ImageEditorSlice(
            id: sliceID,
            name: "  Reveal Hero  ",
            frame: CGRect(x: -5, y: 20, width: 20, height: 10),
            exportPresets: presets
        )]
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = sliceID

        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let revealResponse = registry.execute(request(
            name: "xomo.canvas.transform",
            arguments: ["action": .string("revealAll")]
        ))
        #expect(revealResponse.ok)

        let listResponse = registry.execute(request(name: "xomo.slice.list"))
        #expect(listResponse.ok)
        let slices = try #require(listResponse.result?.arrayValue)
        #expect(slices.count == 1)
        let slice = try #require(slices.first?.objectValue)
        #expect(slice["id"] == .string(sliceID.uuidString))
        #expect(slice["name"] == .string("  Reveal Hero  "))
        #expect(slice["x"] == .number(5))
        #expect(slice["y"] == .number(20))
        #expect(slice["width"] == .number(20))
        #expect(slice["height"] == .number(10))
        #expect(viewModel.document.slices.first?.exportPresets == presets)
        #expect(viewModel.exportSettings.scope == .slice)
        #expect(viewModel.exportSettings.sliceID == sliceID)
        #expect(viewModel.exportSettings.format == .png)
        #expect(viewModel.exportSettings.scale == 2)
        #expect(viewModel.exportSettings.filenameSuffix == "-width")
        let plan = viewModel.selectedSliceExportPlan(settings: viewModel.exportSettings)
        #expect(plan.map(\.settings.format) == [.png, .jpeg, .pdf])
        #expect(plan.map(\.settings.scale) == [2, 2, 1])
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
