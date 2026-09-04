import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoAutomationSliceCanvasResizeTests {
    @Test func registryResizeCanvasOffsetsClipsSlicesAndReprojectsSelectedPreset() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "automation-slice-canvas-resize",
            image: NSImage.transparent(size: CGSize(width: 100, height: 80))
        ) { _ in }
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let keptID = UUID()
        let removedID = UUID()
        let presets = [
            ImageEditorSliceExportPreset(suffix: "-width", format: .png, constraint: .width, value: 40),
            ImageEditorSliceExportPreset(suffix: "-height", format: .jpeg, constraint: .height, value: 20),
            ImageEditorSliceExportPreset(suffix: "-vector", format: .pdf, constraint: .scale, value: 1)
        ]
        viewModel.document.slices = [
            ImageEditorSlice(
                id: keptID,
                name: "Responsive Hero",
                frame: CGRect(x: 10, y: 30, width: 20, height: 10),
                exportPresets: presets
            ),
            ImageEditorSlice(
                id: removedID,
                name: "Outside",
                frame: CGRect(x: 80, y: 20, width: 10, height: 10)
            )
        ]
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = keptID

        let resizeResponse = registry.execute(request(
            name: "xomo.canvas.resize_canvas",
            arguments: [
                "width": .number(60),
                "height": .number(40),
                "anchor": .string(ImageEditorCanvasAnchor.center.rawValue)
            ]
        ))
        #expect(resizeResponse.ok)

        let listResponse = registry.execute(request(name: "xomo.slice.list"))
        #expect(listResponse.ok)
        let slices = try #require(listResponse.result?.arrayValue)
        #expect(slices.count == 1)
        let slice = try #require(slices.first?.objectValue)
        #expect(slice["id"] == .string(keptID.uuidString))
        #expect(slice["name"] == .string("Responsive Hero"))
        #expect(slice["x"] == .number(0))
        #expect(slice["y"] == .number(10))
        #expect(slice["width"] == .number(10))
        #expect(slice["height"] == .number(10))
        #expect(viewModel.document.slices.first?.exportPresets == presets)
        #expect(viewModel.exportSettings.scope == .slice)
        #expect(viewModel.exportSettings.sliceID == keptID)
        #expect(viewModel.exportSettings.format == .png)
        #expect(viewModel.exportSettings.scale == 4)
        #expect(viewModel.exportSettings.filenameSuffix == "-width")
        let plan = viewModel.selectedSliceExportPlan(settings: viewModel.exportSettings)
        #expect(plan.map(\.settings.format) == [.png, .jpeg, .pdf])
        #expect(plan.map(\.settings.scale) == [4, 2, 1])
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
