import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorHotspotOrthogonalTransformTests {
    private let canvasSize = CGSize(width: 100, height: 80)
    private let primaryID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let sentinelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    @Test
    func modelGeometryStandardizesOnceAndPreservesMetadata() throws {
        let source = ImageEditorHotspot(
            id: primaryID,
            name: "  Primary CTA  ",
            frame: CGRect(x: 30.75, y: 24.25, width: -12.5, height: -8.5),
            url: "  https://example.com/primary  "
        )
        let expectations: [(ImageEditorCanvasOrthogonalTransform, CGSize, CGRect)] = [
            (.clockwise90, CGSize(width: 80, height: 100), CGRect(x: 55, y: 18, width: 10, height: 13)),
            (.counterclockwise90, CGSize(width: 80, height: 100), CGRect(x: 15, y: 69, width: 10, height: 13)),
            (.rotate180, canvasSize, CGRect(x: 69, y: 55, width: 13, height: 10)),
            (.flipHorizontal, canvasSize, CGRect(x: 69, y: 15, width: 13, height: 10)),
            (.flipVertical, canvasSize, CGRect(x: 18, y: 55, width: 13, height: 10))
        ]

        for (transform, expectedCanvasSize, expectedFrame) in expectations {
            let transformed = try source.transformedForOrthogonalCanvas(
                transform,
                sourceCanvasSize: canvasSize
            )
            #expect(try transform.targetCanvasSize(for: canvasSize) == expectedCanvasSize)
            #expect(transformed.frame == expectedFrame)
            #expect(transformed.id == source.id)
            #expect(transformed.name == source.name)
            #expect(transformed.url == source.url)
        }
    }

    @Test
    func directCommandsTransformHotspotsAndRoundTripUndoRedo() throws {
        let expectations: [(ImageEditorCanvasOrthogonalTransform, CGSize, [CGRect])] = [
            (
                .clockwise90,
                CGSize(width: 80, height: 100),
                [CGRect(x: 55, y: 18, width: 10, height: 13), CGRect(x: 22, y: 70, width: 8, height: 12)]
            ),
            (
                .counterclockwise90,
                CGSize(width: 80, height: 100),
                [CGRect(x: 15, y: 69, width: 10, height: 13), CGRect(x: 50, y: 18, width: 8, height: 12)]
            ),
            (
                .rotate180,
                canvasSize,
                [CGRect(x: 69, y: 55, width: 13, height: 10), CGRect(x: 18, y: 22, width: 12, height: 8)]
            ),
            (
                .flipHorizontal,
                canvasSize,
                [CGRect(x: 69, y: 15, width: 13, height: 10), CGRect(x: 18, y: 50, width: 12, height: 8)]
            ),
            (
                .flipVertical,
                canvasSize,
                [CGRect(x: 18, y: 55, width: 13, height: 10), CGRect(x: 70, y: 22, width: 12, height: 8)]
            )
        ]

        for (transform, expectedCanvasSize, expectedFrames) in expectations {
            let viewModel = makeViewModel()
            apply(.flipHorizontal, to: viewModel)
            viewModel.undo()
            #expect(viewModel.redoStack.count == 1)
            let originalHotspots = viewModel.document.hotspots
            let originalDocument = try projectData(viewModel.document)
            let originalHistoryCount = viewModel.document.history.count
            viewModel.selectedHotspotID = sentinelID
            viewModel.canvasOffset = CGSize(width: 17, height: -9)
            viewModel.isHotspotsPanelVisible = true
            viewModel.isSlicesPanelVisible = true

            apply(transform, to: viewModel)

            #expect(viewModel.document.canvasSize == expectedCanvasSize)
            #expect(viewModel.document.hotspots.map(\.frame) == expectedFrames)
            #expect(viewModel.document.hotspots.map(\.id) == [primaryID, sentinelID])
            #expect(viewModel.document.hotspots.map(\.name) == ["  Primary CTA  ", "Sentinel"])
            #expect(viewModel.document.hotspots.map(\.url) == ["  https://example.com/primary  ", "sentinel://keep"])
            #expect(viewModel.selectedHotspotID == sentinelID)
            #expect(viewModel.document.history.count == originalHistoryCount + 1)
            #expect(viewModel.document.history.last?.title == historyTitle(for: transform))
            #expect(viewModel.undoStack.count == 1)
            #expect(viewModel.redoStack.isEmpty)
            #expect(viewModel.canvasOffset == CGSize(width: 17, height: -9))
            #expect(viewModel.isHotspotsPanelVisible)
            #expect(viewModel.isSlicesPanelVisible)
            #expect(viewModel.targetImageWidth == Double(expectedCanvasSize.width))
            #expect(viewModel.targetImageHeight == Double(expectedCanvasSize.height))
            #expect(viewModel.targetCanvasWidth == Double(expectedCanvasSize.width))
            #expect(viewModel.targetCanvasHeight == Double(expectedCanvasSize.height))
            let transformedDocument = try projectData(viewModel.document)

            viewModel.undo()
            #expect(try projectData(viewModel.document) == originalDocument)
            #expect(viewModel.document.hotspots == originalHotspots)
            #expect(viewModel.selectedHotspotID == sentinelID)
            #expect(viewModel.targetImageWidth == Double(canvasSize.width))
            #expect(viewModel.targetImageHeight == Double(canvasSize.height))
            #expect(viewModel.targetCanvasWidth == Double(canvasSize.width))
            #expect(viewModel.targetCanvasHeight == Double(canvasSize.height))

            viewModel.redo()
            #expect(try projectData(viewModel.document) == transformedDocument)
            #expect(viewModel.document.hotspots.map(\.frame) == expectedFrames)
            #expect(viewModel.selectedHotspotID == sentinelID)
            #expect(viewModel.targetImageWidth == Double(expectedCanvasSize.width))
            #expect(viewModel.targetImageHeight == Double(expectedCanvasSize.height))
            #expect(viewModel.targetCanvasWidth == Double(expectedCanvasSize.width))
            #expect(viewModel.targetCanvasHeight == Double(expectedCanvasSize.height))
        }
    }

    @Test
    func directCommandsRepairOnlyStaleNonNilHotspotSelection() {
        for transform in ImageEditorCanvasOrthogonalTransform.allCases {
            let staleSelectionModel = makeViewModel()
            staleSelectionModel.selectedHotspotID = UUID()
            apply(transform, to: staleSelectionModel)
            #expect(staleSelectionModel.selectedHotspotID == primaryID)

            let nilSelectionModel = makeViewModel()
            nilSelectionModel.selectedHotspotID = nil
            apply(transform, to: nilSelectionModel)
            #expect(nilSelectionModel.selectedHotspotID == nil)

            let emptyModel = makeViewModel()
            emptyModel.document.hotspots = []
            emptyModel.selectedHotspotID = UUID()
            apply(transform, to: emptyModel)
            #expect(emptyModel.selectedHotspotID == nil)
        }
    }

    @Test
    func nonCanvasUndoRedoPreservesPendingSizeControlInput() throws {
        let viewModel = makeViewModel()
        let selectedLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerVisibility(selectedLayerID)
        viewModel.targetImageWidth = 321
        viewModel.targetImageHeight = 654
        viewModel.targetCanvasWidth = 987
        viewModel.targetCanvasHeight = 456

        viewModel.undo()
        #expect(viewModel.targetImageWidth == 321)
        #expect(viewModel.targetImageHeight == 654)
        #expect(viewModel.targetCanvasWidth == 987)
        #expect(viewModel.targetCanvasHeight == 456)

        viewModel.redo()
        #expect(viewModel.targetImageWidth == 321)
        #expect(viewModel.targetImageHeight == 654)
        #expect(viewModel.targetCanvasWidth == 987)
        #expect(viewModel.targetCanvasHeight == 456)
    }

    @Test
    func invalidGeometryRejectsEveryCommandAtomically() throws {
        let invalidMutations: [(ImageEditorViewModel) -> Void] = [
            { $0.document.canvasSize = CGSize(width: 0, height: 80) },
            { $0.document.canvasSize = CGSize(width: -100, height: 80) },
            { $0.document.canvasSize = CGSize(width: CGFloat.nan, height: 80) },
            { $0.document.canvasSize = CGSize(width: CGFloat.infinity, height: 80) },
            { $0.document.hotspots[0].frame.size.width = 0 },
            { $0.document.hotspots[0].frame.origin.x = CGFloat.nan },
            { $0.document.hotspots[0].frame.size.height = CGFloat.infinity },
            { $0.document.hotspots[0].frame = CGRect(x: 95, y: 10, width: 10, height: 10) },
            {
                $0.document.hotspots[0].frame = CGRect(
                    x: CGFloat.greatestFiniteMagnitude,
                    y: 10,
                    width: CGFloat.greatestFiniteMagnitude,
                    height: 10
                )
            },
            { $0.document.layers[0].frame.origin.x = CGFloat.nan }
        ]

        for transform in ImageEditorCanvasOrthogonalTransform.allCases {
            for mutate in invalidMutations {
                let viewModel = makeViewModel()
                apply(.flipHorizontal, to: viewModel)
                viewModel.undo()
                viewModel.selectedHotspotID = sentinelID
                viewModel.canvasOffset = CGSize(width: 13, height: -7)
                viewModel.isHotspotsPanelVisible = true
                viewModel.isSlicesPanelVisible = true
                viewModel.targetImageWidth = 321
                viewModel.targetImageHeight = 654
                viewModel.targetCanvasWidth = 987
                viewModel.targetCanvasHeight = 456
                mutate(viewModel)
                let before = try transactionSnapshot(viewModel)

                apply(transform, to: viewModel)

                #expect(try transactionSnapshot(viewModel) == before)
                #expect(viewModel.selectedHotspotID == sentinelID)
                #expect(viewModel.canvasOffset == CGSize(width: 13, height: -7))
                #expect(viewModel.isHotspotsPanelVisible)
                #expect(viewModel.isSlicesPanelVisible)
                #expect(viewModel.targetImageWidth == 321)
                #expect(viewModel.targetImageHeight == 654)
                #expect(viewModel.targetCanvasWidth == 987)
                #expect(viewModel.targetCanvasHeight == 456)
                #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
            }
        }
    }

    private func makeViewModel() -> ImageEditorViewModel {
        let viewModel = ImageEditorViewModel(
            sourceName: "orthogonal-hotspots.png",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        viewModel.document.hotspots = [
            ImageEditorHotspot(
                id: primaryID,
                name: "  Primary CTA  ",
                frame: CGRect(x: 30.75, y: 24.25, width: -12.5, height: -8.5),
                url: "  https://example.com/primary  "
            ),
            ImageEditorHotspot(
                id: sentinelID,
                name: "Sentinel",
                frame: CGRect(x: 70, y: 50, width: 12, height: 8),
                url: "sentinel://keep"
            )
        ]
        return viewModel
    }

    private func apply(
        _ transform: ImageEditorCanvasOrthogonalTransform,
        to viewModel: ImageEditorViewModel
    ) {
        switch transform {
        case .clockwise90:
            viewModel.rotateClockwise()
        case .counterclockwise90:
            viewModel.rotateCounterclockwise()
        case .rotate180:
            viewModel.rotate180()
        case .flipHorizontal:
            viewModel.flipHorizontal()
        case .flipVertical:
            viewModel.flipVertical()
        }
    }

    private func historyTitle(for transform: ImageEditorCanvasOrthogonalTransform) -> String {
        switch transform {
        case .clockwise90:
            L10n.text("imageEditor.history.rotateClockwise")
        case .counterclockwise90:
            L10n.text("imageEditor.history.rotateCounterclockwise")
        case .rotate180:
            L10n.text("imageEditor.history.rotate180")
        case .flipHorizontal:
            L10n.text("imageEditor.history.flipHorizontal")
        case .flipVertical:
            L10n.text("imageEditor.history.flipVertical")
        }
    }

    private func transactionSnapshot(_ viewModel: ImageEditorViewModel) throws -> TransactionSnapshot {
        TransactionSnapshot(
            document: try projectData(viewModel.document),
            undo: try viewModel.undoStack.map { try projectData($0) },
            redo: try viewModel.redoStack.map { try projectData($0) }
        )
    }

    private func projectData(_ document: ImageEditorDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return try encoder.encode(ImageEditorProjectDocument(document: document))
    }

    private struct TransactionSnapshot: Equatable {
        let document: Data
        let undo: [Data]
        let redo: [Data]
    }
}
