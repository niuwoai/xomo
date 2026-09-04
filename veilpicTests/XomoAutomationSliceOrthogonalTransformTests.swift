import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoAutomationSliceOrthogonalTransformTests {
    @Test
    func fiveCanvasActionsExposeTransformedSliceAndRealExportPlan() throws {
        let expectations: [(String, CGSize, CGRect, Double)] = [
            ("rotateClockwise", CGSize(width: 80, height: 100), CGRect(x: 40, y: 10, width: 20, height: 40), 2),
            ("rotateCounterclockwise", CGSize(width: 80, height: 100), CGRect(x: 20, y: 50, width: 20, height: 40), 2),
            ("rotate180", CGSize(width: 100, height: 80), CGRect(x: 50, y: 40, width: 40, height: 20), 1),
            ("flipHorizontal", CGSize(width: 100, height: 80), CGRect(x: 50, y: 20, width: 40, height: 20), 1),
            ("flipVertical", CGSize(width: 100, height: 80), CGRect(x: 10, y: 40, width: 40, height: 20), 1)
        ]

        for (action, expectedSize, expectedFrame, expectedScale) in expectations {
            let viewModel = ImageEditorViewModel(
                sourceName: "automation-slice-orthogonal",
                image: NSImage.transparent(size: CGSize(width: 100, height: 80))
            ) { _ in }
            let sliceID = UUID()
            let presets = [
                ImageEditorSliceExportPreset(suffix: "-width", format: .png, constraint: .width, value: 40),
                ImageEditorSliceExportPreset(suffix: "-height", format: .jpeg, constraint: .height, value: 40),
                ImageEditorSliceExportPreset(suffix: "-vector", format: .pdf, constraint: .scale, value: 1)
            ]
            viewModel.document.slices = [ImageEditorSlice(
                id: sliceID,
                name: "  Automation delivery  ",
                frame: CGRect(x: 10, y: 20, width: 40, height: 20),
                exportPresets: presets
            )]
            viewModel.exportSettings.scope = .slice
            viewModel.exportSettings.sliceID = sliceID

            try withRegistered(viewModel) { registry in
                let transformResponse = registry.execute(request(
                    name: "xomo.canvas.transform",
                    arguments: ["action": .string(action)]
                ))
                #expect(transformResponse.ok)
                #expect(viewModel.document.canvasSize == expectedSize)

                let listResponse = registry.execute(request(name: "xomo.slice.list"))
                #expect(listResponse.ok)
                let slices = try #require(listResponse.result?.arrayValue)
                let slice = try #require(slices.first?.objectValue)
                #expect(slices.count == 1)
                #expect(slice["id"] == .string(sliceID.uuidString))
                #expect(slice["name"] == .string("  Automation delivery  "))
                #expect(slice["x"] == .number(Double(expectedFrame.minX)))
                #expect(slice["y"] == .number(Double(expectedFrame.minY)))
                #expect(slice["width"] == .number(Double(expectedFrame.width)))
                #expect(slice["height"] == .number(Double(expectedFrame.height)))
                #expect(viewModel.document.slices.first?.exportPresets == presets)
                #expect(viewModel.exportSettings.scope == .slice)
                #expect(viewModel.exportSettings.sliceID == sliceID)
                #expect(viewModel.exportSettings.scale == expectedScale)
                #expect(viewModel.exportSettings.filenameSuffix == "-width")

                let plan = viewModel.selectedSliceExportPlan(settings: viewModel.exportSettings)
                #expect(plan.map(\.settings.format) == [.png, .jpeg, .pdf])
                let expectedHeightScale = expectedFrame.height == 40 ? 1.0 : 2.0
                #expect(plan.map(\.settings.scale) == [expectedScale, expectedHeightScale, 1])
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
