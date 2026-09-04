import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoAutomationSliceCropTrimTests {
    @Test func automationCropToSelectionReportsTransformedSliceAndPresetProjection() throws {
        let viewModel = makeViewModel(named: "automation-slice-crop-selection")
        let id = UUID()
        let presets = deliveryPresets()
        viewModel.document.selection = .rectangle(CGRect(x: 20, y: 10, width: 50, height: 40))
        viewModel.document.slices = [
            ImageEditorSlice(
                id: id,
                name: "Selection Hero",
                frame: CGRect(x: 10, y: 20, width: 20, height: 10),
                exportPresets: presets
            ),
            ImageEditorSlice(name: "Removed", frame: CGRect(x: 80, y: 60, width: 10, height: 10))
        ]
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = id

        try withRegistered(viewModel) { registry in
            #expect(registry.execute(request(name: "xomo.canvas.crop_to_selection")).ok)
            try expectSingleSlice(registry, id: id, name: "Selection Hero", frame: CGRect(x: 0, y: 10, width: 10, height: 10))
        }
        #expect(viewModel.document.slices.first?.exportPresets == presets)
        #expect(viewModel.exportSettings.scope == .slice)
        #expect(viewModel.exportSettings.sliceID == id)
        #expect(viewModel.exportSettings.format == .png)
        #expect(viewModel.exportSettings.scale == 4)
        #expect(viewModel.exportSettings.filenameSuffix == "-width")
        #expect(viewModel.selectedSliceExportPlan(settings: viewModel.exportSettings).map(\.settings.scale) == [4, 2, 1])
    }

    @Test func automationTrimTransparentReportsTransformedSlice() throws {
        let viewModel = makeViewModel(named: "automation-slice-trim")
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 30, y: 22, width: 20, height: 16)
        viewModel.document.layers[layerIndex].image = NSImage.opaqueMask(size: CGSize(width: 20, height: 16))
        let id = UUID()
        viewModel.document.slices = [
            ImageEditorSlice(id: id, name: "Trim Hero", frame: CGRect(x: 35, y: 27, width: 10, height: 8)),
            ImageEditorSlice(name: "Outside", frame: CGRect(x: 80, y: 60, width: 10, height: 8))
        ]

        try withRegistered(viewModel) { registry in
            #expect(registry.execute(request(
                name: "xomo.canvas.transform",
                arguments: ["action": .string("trimTransparent")]
            )).ok)
            try expectSingleSlice(registry, id: id, name: "Trim Hero", frame: CGRect(x: 5, y: 5, width: 10, height: 8))
        }
    }

    private func makeViewModel(named name: String) -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: name,
            image: NSImage.transparent(size: CGSize(width: 100, height: 80))
        ) { _ in }
    }

    private func deliveryPresets() -> [ImageEditorSliceExportPreset] {
        [
            ImageEditorSliceExportPreset(suffix: "-width", format: .png, constraint: .width, value: 40),
            ImageEditorSliceExportPreset(suffix: "-height", format: .jpeg, constraint: .height, value: 20),
            ImageEditorSliceExportPreset(suffix: "-vector", format: .pdf, constraint: .scale, value: 1)
        ]
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

    private func expectSingleSlice(
        _ registry: XomoAutomationRegistry,
        id: UUID,
        name: String,
        frame: CGRect
    ) throws {
        let response = registry.execute(request(name: "xomo.slice.list"))
        #expect(response.ok)
        let slices = try #require(response.result?.arrayValue)
        #expect(slices.count == 1)
        let slice = try #require(slices.first?.objectValue)
        #expect(slice["id"] == .string(id.uuidString))
        #expect(slice["name"] == .string(name))
        #expect(slice["x"] == .number(Double(frame.minX)))
        #expect(slice["y"] == .number(Double(frame.minY)))
        #expect(slice["width"] == .number(Double(frame.width)))
        #expect(slice["height"] == .number(Double(frame.height)))
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
