import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorEffectiveSelectionAutomationTests {
    private let canvasSize = CGSize(width: 40, height: 30)

    @Test func emptyPixelSelectionIsNotAnActiveAutomationSelection() {
        let viewModel = makeViewModel()
        viewModel.document.selection = emptyRasterSelection()
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count
        let originalStatus = viewModel.statusText

        #expect(viewModel.hasSelection)
        #expect(!viewModel.hasEffectiveSelectionPixels)
        #expect(!viewModel.canSelectSimilarColors)
        #expect(!viewModel.canGrowColorSelection)
        #expect(!viewModel.canSaveSelectionAsAlphaChannel)

        for request in directRequests() + modifyRequests() + pixelEditRequests() {
            let response = registry.execute(request)
            #expect(!response.ok)
            #expect(response.error?.contains("requires an active selection") == true)
        }

        #expect(viewModel.document.selection == emptyRasterSelection())
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.statusText == originalStatus)
    }

    private func directRequests() -> [XomoAutomationWireRequest] {
        [
            request(name: "xomo.selection.invert"),
            request(name: "xomo.selection.feather", arguments: ["radius": .number(3)]),
            request(name: "xomo.selection.smooth", arguments: ["radius": .number(3)])
        ]
    }

    private func modifyRequests() -> [XomoAutomationWireRequest] {
        let actions = [
            "save", "similarColors", "growColor", "expand", "contract", "border",
            "smooth", "fillHoles", "removeSpeckles", "centerHorizontal",
            "centerVertical", "centerCanvas", "flipHorizontal", "flipVertical",
            "rotateClockwise", "rotateCounterclockwise", "rotate180", "scaleUp",
            "scaleDown", "fitCanvas", "nudge"
        ]
        return actions.map { action in
            var arguments: [String: XomoJSONValue] = ["action": .string(action)]
            if ["similarColors", "growColor"].contains(action) {
                arguments["tolerance"] = .number(0.1)
            }
            if ["expand", "contract", "border", "smooth", "removeSpeckles"].contains(action) {
                arguments["amount"] = .number(2)
            }
            if action == "nudge" {
                arguments["dx"] = .number(1)
                arguments["dy"] = .number(0)
            }
            return request(name: "xomo.selection.modify", arguments: arguments)
        }
    }

    private func pixelEditRequests() -> [XomoAutomationWireRequest] {
        [
            "fillForeground", "fillBackground", "stroke", "contentAwareFill",
            "clearPixels", "copyToLayer", "cutToLayer"
        ].map { action in
            request(
                name: "xomo.selection.edit",
                arguments: ["action": .string(action)]
            )
        }
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "effective-selection-automation",
            image: .transparent(size: canvasSize)
        ) { _ in }
    }

    private func emptyRasterSelection() -> ImageEditorSelection {
        .raster(
            mask: ImageEditorSelectionMask(
                width: Int(canvasSize.width),
                height: Int(canvasSize.height),
                alpha: [UInt8](
                    repeating: 0,
                    count: Int(canvasSize.width * canvasSize.height)
                )
            ),
            bounds: CGRect(origin: .zero, size: canvasSize)
        )
    }

    private func request(
        name: String,
        arguments: [String: XomoJSONValue] = [:]
    ) -> XomoAutomationWireRequest {
        XomoAutomationWireRequest(
            token: "test",
            operation: "call",
            name: name,
            arguments: arguments
        )
    }
}
