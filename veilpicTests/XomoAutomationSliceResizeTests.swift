import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoAutomationSliceResizeTests {
    @Test func registryResizeImageScalesSlicesAndReprojectsSelectedPreset() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "automation-slice-resize",
            image: NSImage.transparent(size: CGSize(width: 320, height: 240))
        ) { _ in }
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let sliceID = UUID()
        let presets = [
            ImageEditorSliceExportPreset(
                suffix: "-width",
                format: .png,
                constraint: .width,
                value: 99
            ),
            ImageEditorSliceExportPreset(
                suffix: "-height",
                format: .jpeg,
                constraint: .height,
                value: 117
            ),
            ImageEditorSliceExportPreset(
                suffix: "-vector",
                format: .pdf,
                constraint: .scale,
                value: 1
            )
        ]
        viewModel.document.slices = [ImageEditorSlice(
            id: sliceID,
            name: "Responsive Hero",
            frame: CGRect(x: 20.4, y: 40.4, width: 64.4, height: 38.6),
            exportPresets: presets
        )]
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = sliceID

        let resizeResponse = registry.execute(request(
            name: "xomo.canvas.resize_image",
            arguments: [
                "width": .number(160),
                "height": .number(480)
            ]
        ))
        #expect(resizeResponse.ok)

        let listResponse = registry.execute(request(name: "xomo.slice.list"))
        #expect(listResponse.ok)
        let listedSlice = try #require(listResponse.result?.arrayValue?.first?.objectValue)
        #expect(listedSlice["id"] == .string(sliceID.uuidString))
        #expect(listedSlice["name"] == .string("Responsive Hero"))
        #expect(listedSlice["x"] == .number(10))
        #expect(listedSlice["y"] == .number(80))
        #expect(listedSlice["width"] == .number(33))
        #expect(listedSlice["height"] == .number(78))
        #expect(viewModel.document.slices.first?.exportPresets == presets)
        #expect(viewModel.exportSettings.scope == .slice)
        #expect(viewModel.exportSettings.sliceID == sliceID)
        #expect(viewModel.exportSettings.format == .png)
        #expect(viewModel.exportSettings.scale == 3)
        #expect(viewModel.exportSettings.filenameSuffix == "-width")
        let plan = viewModel.selectedSliceExportPlan(settings: viewModel.exportSettings)
        #expect(plan.map(\.settings.scale) == [3, 1.5, 1])
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
