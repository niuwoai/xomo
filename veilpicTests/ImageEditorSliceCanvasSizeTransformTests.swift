import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSliceCanvasSizeTransformTests {
    @Test func helperUsesFloatingEdgesThenOneIntegralAndPreservesMetadataShapes() throws {
        let id = UUID()
        let presets = deliveryPresets()
        let source = ImageEditorSlice(
            id: id,
            name: "  Raw Slice Name  ",
            frame: CGRect(x: 30.4, y: 27.6, width: -20.2, height: -15.2),
            exportPresets: presets
        )

        let transformed = try source.offsetForCanvasResize(
            offset: CGSize(width: -20.5, height: -20.5),
            sourceCanvasSize: CGSize(width: 101, height: 81),
            targetCanvasSize: CGSize(width: 60, height: 40)
        )

        #expect(transformed?.frame == CGRect(x: 0, y: 0, width: 10, height: 8))
        #expect(transformed?.id == id)
        #expect(transformed?.name == source.name)
        #expect(transformed?.exportPresets == presets)

        var explicitEmpty = ImageEditorSlice(
            name: "Empty delivery list",
            frame: CGRect(x: 30, y: 30, width: 10, height: 10)
        )
        explicitEmpty.exportPresets = []
        let emptyResult = try explicitEmpty.offsetForCanvasResize(
            offset: .zero,
            sourceCanvasSize: CGSize(width: 100, height: 80),
            targetCanvasSize: CGSize(width: 60, height: 40)
        )
        let requiredEmpty = try #require(emptyResult)
        #expect(requiredEmpty.exportPresets != nil)
        #expect(requiredEmpty.exportPresets?.isEmpty == true)

        let nilPresets = ImageEditorSlice(
            name: "Legacy nil",
            frame: CGRect(x: 30, y: 30, width: 10, height: 10)
        )
        let nilResult = try nilPresets.offsetForCanvasResize(
            offset: .zero,
            sourceCanvasSize: CGSize(width: 100, height: 80),
            targetCanvasSize: CGSize(width: 60, height: 40)
        )
        let requiredNil = try #require(nilResult)
        #expect(requiredNil.exportPresets == nil)

        let historical = ImageEditorSlice(
            name: "Historical straddle",
            frame: CGRect(x: -10.2, y: 10.4, width: 30.4, height: 20.2)
        )
        let historicalResult = try historical.offsetForCanvasResize(
            offset: CGSize(width: 20, height: 0),
            sourceCanvasSize: CGSize(width: 100, height: 80),
            targetCanvasSize: CGSize(width: 140, height: 120)
        )
        #expect(historicalResult?.frame == CGRect(x: 9, y: 10, width: 32, height: 21))
    }

    @Test func canvasResizeOffsetsSlicesForAllNineAnchorsWithoutScaling() {
        let id = UUID()
        let presets = deliveryPresets()
        let source = ImageEditorSlice(
            id: id,
            name: "Anchor Slice",
            frame: CGRect(x: 12, y: 14, width: 18, height: 10),
            exportPresets: presets
        )
        let cases: [(ImageEditorCanvasAnchor, CGSize)] = [
            (.topLeft, CGSize(width: 0, height: 40)),
            (.top, CGSize(width: 20, height: 40)),
            (.topRight, CGSize(width: 40, height: 40)),
            (.left, CGSize(width: 0, height: 20)),
            (.center, CGSize(width: 20, height: 20)),
            (.right, CGSize(width: 40, height: 20)),
            (.bottomLeft, .zero),
            (.bottom, CGSize(width: 20, height: 0)),
            (.bottomRight, CGSize(width: 40, height: 0))
        ]

        for (anchor, offset) in cases {
            let viewModel = makeViewModel()
            viewModel.document.slices = [source]

            viewModel.resizeCanvas(to: CGSize(width: 140, height: 120), anchor: anchor)

            #expect(viewModel.document.slices.first?.frame == CGRect(
                x: source.frame.minX + offset.width,
                y: source.frame.minY + offset.height,
                width: source.frame.width,
                height: source.frame.height
            ))
            #expect(viewModel.document.slices.first?.id == id)
            #expect(viewModel.document.slices.first?.name == source.name)
            #expect(viewModel.document.slices.first?.exportPresets == presets)
        }
    }

    @Test func commandClipsAndRemovesSlicesWhilePreservingSurvivorOrder() {
        let ids = (0..<5).map { _ in UUID() }
        let viewModel = makeViewModel()
        viewModel.document.slices = [
            ImageEditorSlice(id: ids[0], name: "Kept", frame: CGRect(x: 25, y: 25, width: 20, height: 10)),
            ImageEditorSlice(id: ids[1], name: "Clipped", frame: CGRect(x: 10, y: 10, width: 15, height: 15)),
            ImageEditorSlice(id: ids[2], name: "Touching", frame: CGRect(x: 80, y: 20, width: 10, height: 10)),
            ImageEditorSlice(id: ids[3], name: "Outside", frame: CGRect(x: 90, y: 60, width: 5, height: 5)),
            ImageEditorSlice(id: ids[4], name: "Trailing", frame: CGRect(x: 65, y: 45, width: 15, height: 15))
        ]

        viewModel.resizeCanvas(to: CGSize(width: 60, height: 40), anchor: .center)

        #expect(viewModel.document.slices.map(\.id) == [ids[0], ids[1], ids[4]])
        #expect(viewModel.document.slices.map(\.name) == ["Kept", "Clipped", "Trailing"])
        #expect(viewModel.document.slices.map(\.frame) == [
            CGRect(x: 5, y: 5, width: 20, height: 10),
            CGRect(x: 0, y: 0, width: 5, height: 5),
            CGRect(x: 45, y: 25, width: 15, height: 15)
        ])
    }

    @Test func helperValidatesAllPresetKindsAgainstSourceAndSurvivingTarget() throws {
        let presets = deliveryPresets()
        let source = ImageEditorSlice(
            name: "Delivery",
            frame: CGRect(x: 20, y: 20, width: 40, height: 20),
            exportPresets: presets
        )
        let transformed = try source.offsetForCanvasResize(
            offset: CGSize(width: -10, height: -10),
            sourceCanvasSize: CGSize(width: 100, height: 80),
            targetCanvasSize: CGSize(width: 60, height: 40)
        )
        let target = try #require(transformed)
        #expect(target.frame == CGRect(x: 10, y: 10, width: 40, height: 20))
        #expect(target.exportPresets == presets)
        #expect(presets.map { $0.resolvedScale(for: source.frame)! } == [1, 1, 1])
        #expect(presets.map { $0.resolvedScale(for: target.frame)! } == [1, 1, 1])

        let sourceBoundaryPreset = ImageEditorSliceExportPreset(
            suffix: "source-integral",
            format: .png,
            constraint: .width,
            value: 16.2
        )
        let fractional = ImageEditorSlice(
            name: "Fractional",
            frame: CGRect(x: 20.4, y: 10, width: 64.4, height: 20),
            exportPresets: [sourceBoundaryPreset]
        )
        #expect(sourceBoundaryPreset.resolvedScale(for: fractional.frame.standardized) != nil)
        #expect(throws: (any Error).self) {
            _ = try fractional.offsetForCanvasResize(
                offset: .zero,
                sourceCanvasSize: CGSize(width: 100, height: 80),
                targetCanvasSize: CGSize(width: 100, height: 80)
            )
        }

        let historicalOutsidePreset = ImageEditorSliceExportPreset(
            suffix: "source-visible-width",
            format: .png,
            constraint: .width,
            value: 200
        )
        let historicalOutside = ImageEditorSlice(
            name: "Historical outside source",
            frame: CGRect(x: -20, y: 10, width: 60, height: 20),
            exportPresets: [historicalOutsidePreset]
        )
        #expect(historicalOutsidePreset.resolvedScale(for: historicalOutside.frame.standardized) != nil)
        #expect(throws: (any Error).self) {
            _ = try historicalOutside.offsetForCanvasResize(
                offset: .zero,
                sourceCanvasSize: CGSize(width: 100, height: 80),
                targetCanvasSize: CGSize(width: 100, height: 80)
            )
        }

        let targetInvalid = ImageEditorSlice(
            name: "Target invalid",
            frame: CGRect(x: 0, y: 0, width: 100, height: 80),
            exportPresets: [
                ImageEditorSliceExportPreset(
                    suffix: "target-height",
                    format: .jpeg,
                    constraint: .height,
                    value: 240
                )
            ]
        )
        #expect(throws: (any Error).self) {
            _ = try targetInvalid.offsetForCanvasResize(
                offset: .zero,
                sourceCanvasSize: CGSize(width: 100, height: 80),
                targetCanvasSize: CGSize(width: 60, height: 40)
            )
        }
    }

    @Test func helperRejectsInvalidCanvasAndOffsetGeometryInsteadOfReportingRemoval() {
        let slice = ImageEditorSlice(
            name: "Geometry",
            frame: CGRect(x: 10, y: 10, width: 20, height: 20)
        )
        let cases: [(CGSize, CGSize, CGSize)] = [
            (CGSize(width: CGFloat.nan, height: 0), CGSize(width: 100, height: 80), CGSize(width: 60, height: 40)),
            (.zero, CGSize(width: 0, height: 80), CGSize(width: 60, height: 40)),
            (.zero, CGSize(width: 100, height: 80), CGSize(width: 0, height: 40)),
            (.zero, CGSize(width: 100, height: 80), CGSize(width: CGFloat.infinity, height: 40))
        ]
        for (offset, sourceSize, targetSize) in cases {
            #expect(throws: (any Error).self) {
                _ = try slice.offsetForCanvasResize(
                    offset: offset,
                    sourceCanvasSize: sourceSize,
                    targetCanvasSize: targetSize
                )
            }
        }
    }

    @Test func validRemovalStillRejectsInvalidSourcePreset() throws {
        let validRemoved = ImageEditorSlice(
            name: "Removed valid delivery",
            frame: CGRect(x: 80, y: 20, width: 10, height: 10),
            exportPresets: [ImageEditorSliceExportPreset(
                suffix: "valid-boundary",
                format: .png,
                constraint: .width,
                value: 40
            )]
        )
        let validResult = try validRemoved.offsetForCanvasResize(
            offset: CGSize(width: -20, height: -20),
            sourceCanvasSize: CGSize(width: 100, height: 80),
            targetCanvasSize: CGSize(width: 60, height: 40)
        )
        #expect(validResult == nil)

        let removed = ImageEditorSlice(
            name: "Removed invalid delivery",
            frame: CGRect(x: 80, y: 20, width: 10, height: 10),
            exportPresets: [ImageEditorSliceExportPreset(
                suffix: "invalid-boundary",
                format: .png,
                constraint: .width,
                value: 41
            )]
        )
        #expect(throws: (any Error).self) {
            _ = try removed.offsetForCanvasResize(
                offset: CGSize(width: -20, height: -20),
                sourceCanvasSize: CGSize(width: 100, height: 80),
                targetCanvasSize: CGSize(width: 60, height: 40)
            )
        }

        let viewModel = makeViewModel()
        viewModel.document.slices = [removed]
        let before = try atomicSnapshot(viewModel)
        viewModel.resizeCanvas(to: CGSize(width: 60, height: 40), anchor: .center)
        #expect(try atomicSnapshot(viewModel) == before)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
    }

    @Test func sliceExportSelectionMatrixUsesFinalSurvivorsAndPresets() {
        let first = ImageEditorSlice(
            name: "First",
            frame: CGRect(x: 30, y: 30, width: 20, height: 10),
            exportPresets: deliveryPresets()
        )
        let removed = ImageEditorSlice(
            name: "Removed",
            frame: CGRect(x: 80, y: 20, width: 10, height: 10),
            exportPresets: [ImageEditorSliceExportPreset(
                suffix: "@2x",
                format: .jpeg,
                constraint: .scale,
                value: 2
            )]
        )
        let selections: [UUID?] = [first.id, removed.id, nil, UUID()]
        for selection in selections {
            let viewModel = makeViewModel()
            viewModel.document.slices = [first, removed]
            viewModel.exportSettings.scope = .slice
            viewModel.exportSettings.sliceID = selection
            viewModel.exportSettings.filenameSuffix = "stale"

            viewModel.resizeCanvas(to: CGSize(width: 60, height: 40), anchor: .center)

            #expect(viewModel.exportSettings.scope == .slice)
            #expect(viewModel.exportSettings.sliceID == first.id)
            #expect(viewModel.exportSettings.format == .png)
            #expect(viewModel.exportSettings.scale == 2)
            #expect(viewModel.exportSettings.filenameSuffix == "-width")
        }

        let empty = makeViewModel()
        empty.document.slices = [removed]
        empty.exportSettings.scope = .slice
        empty.exportSettings.sliceID = removed.id
        empty.exportSettings.filenameSuffix = "stale"
        empty.resizeCanvas(to: CGSize(width: 60, height: 40), anchor: .center)
        #expect(empty.document.slices.isEmpty)
        #expect(empty.exportSettings.scope == .composited)
        #expect(empty.exportSettings.sliceID == nil)
        #expect(empty.exportSettings.filenameSuffix.isEmpty)

        let nonSlice = makeViewModel()
        nonSlice.document.slices = [first]
        nonSlice.exportSettings = ImageEditorExportSettings(
            format: .jpeg,
            scope: .selectedLayer,
            sliceID: UUID(),
            scale: 3,
            batchScales: [1, 2],
            namingRule: .sourceName,
            quality: 0.42,
            filenameSuffix: "untouched",
            sliceConflictPolicy: .skipExisting
        )
        let settings = nonSlice.exportSettings
        nonSlice.resizeCanvas(to: CGSize(width: 140, height: 120), anchor: .center)
        #expect(nonSlice.exportSettings == settings)

        let noPreset = makeViewModel()
        let noPresetSlice = ImageEditorSlice(
            name: "No preset",
            frame: CGRect(x: 30, y: 30, width: 20, height: 10)
        )
        noPreset.document.slices = [noPresetSlice]
        noPreset.exportSettings.scope = .slice
        noPreset.exportSettings.sliceID = noPresetSlice.id
        noPreset.exportSettings.format = .jpeg
        noPreset.exportSettings.scale = 3
        noPreset.exportSettings.batchScales = [1, 2]
        noPreset.exportSettings.filenameSuffix = "stale"
        noPreset.resizeCanvas(to: CGSize(width: 60, height: 40), anchor: .center)
        #expect(noPreset.exportSettings.scope == .slice)
        #expect(noPreset.exportSettings.sliceID == noPresetSlice.id)
        #expect(noPreset.exportSettings.format == .jpeg)
        #expect(noPreset.exportSettings.scale == 3)
        #expect(noPreset.exportSettings.batchScales == [1, 2])
        #expect(noPreset.exportSettings.filenameSuffix.isEmpty)
    }

    @Test func successfulResizeIsOneTransactionAndUndoRedoRestoresSlicesAndProjection() throws {
        let viewModel = makeViewModel()
        let slice = ImageEditorSlice(
            name: "Hero",
            frame: CGRect(x: 10, y: 30, width: 20, height: 10),
            exportPresets: deliveryPresets()
        )
        viewModel.document.slices = [slice]
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = slice.id
        viewModel.isSlicesPanelVisible = true
        viewModel.isHotspotsPanelVisible = true
        viewModel.canvasOffset = CGSize(width: 8, height: -3)
        viewModel.selectedCanvasAnchor = .center
        viewModel.pushUndo()
        viewModel.document.areGuidesVisible.toggle()
        viewModel.pushUndo()
        viewModel.document.areRulersVisible.toggle()
        viewModel.undo()
        let before = try documentData(viewModel.document)
        let undoCount = viewModel.undoStack.count
        let historyCount = viewModel.document.history.count
        #expect(!viewModel.redoStack.isEmpty)

        viewModel.resizeCanvas(to: CGSize(width: 60, height: 40), anchor: .center)

        let after = try documentData(viewModel.document)
        #expect(viewModel.document.slices.first?.frame == CGRect(x: 0, y: 10, width: 10, height: 10))
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(viewModel.redoStack.isEmpty)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.canvasResize"))
        #expect(viewModel.exportSettings.scale == 4)
        #expect(viewModel.isSlicesPanelVisible)
        #expect(viewModel.isHotspotsPanelVisible)
        #expect(viewModel.canvasOffset == .zero)
        #expect(viewModel.selectedCanvasAnchor.rawValue == ImageEditorCanvasAnchor.center.rawValue)
        #expect(viewModel.targetCanvasWidth == 60)
        #expect(viewModel.targetCanvasHeight == 40)

        viewModel.undo()
        #expect(try documentData(viewModel.document) == before)
        #expect(viewModel.exportSettings.sliceID == slice.id)
        #expect(viewModel.exportSettings.scale == 2)

        viewModel.redo()
        #expect(try documentData(viewModel.document) == after)
        #expect(viewModel.exportSettings.sliceID == slice.id)
        #expect(viewModel.exportSettings.scale == 4)
    }

    @Test func invalidGeometryAndPresetsRejectBeforeUndoWithCompleteAtomicSnapshot() throws {
        let invalidSlices: [ImageEditorSlice] = [
            ImageEditorSlice(name: "Zero", frame: CGRect(x: 10, y: 10, width: 0, height: 20)),
            ImageEditorSlice(name: "NaN", frame: CGRect(x: CGFloat.nan, y: 10, width: 20, height: 20)),
            ImageEditorSlice(name: "Infinity", frame: CGRect(x: 10, y: 10, width: CGFloat.infinity, height: 20)),
            ImageEditorSlice(name: "Overflow", frame: CGRect(x: CGFloat.greatestFiniteMagnitude, y: 0, width: CGFloat.greatestFiniteMagnitude, height: 20)),
            ImageEditorSlice(name: "Source outside", frame: CGRect(x: 400, y: 300, width: 20, height: 20)),
            sliceWithPresets(Array(repeating: ImageEditorSliceExportPreset(suffix: "x", format: .png, constraint: .scale, value: 1), count: ImageEditorSlice.maximumExportPresetCount + 1)),
            sliceWithPresets([ImageEditorSliceExportPreset(suffix: "unsupported", format: .webp, constraint: .scale, value: 1)]),
            sliceWithPresets([ImageEditorSliceExportPreset(suffix: "bad", format: .png, constraint: .scale, value: 0)]),
            sliceWithPresets([ImageEditorSliceExportPreset(suffix: "source", format: .png, constraint: .width, value: 5)]),
            ImageEditorSlice(
                name: "Target scale",
                frame: CGRect(x: 0, y: 0, width: 100, height: 80),
                exportPresets: [ImageEditorSliceExportPreset(suffix: "target", format: .jpeg, constraint: .height, value: 240)]
            )
        ]

        for invalidSlice in invalidSlices {
            let viewModel = makeViewModel()
            viewModel.document.slices = [invalidSlice]
            viewModel.exportSettings.scope = .slice
            viewModel.exportSettings.sliceID = invalidSlice.id
            viewModel.isSlicesPanelVisible = true
            viewModel.isHotspotsPanelVisible = true
            viewModel.canvasOffset = CGSize(width: 7, height: -3)
            viewModel.selectedCanvasAnchor = .topRight
            viewModel.targetImageWidth = 123
            viewModel.targetImageHeight = 124
            viewModel.targetCanvasWidth = 125
            viewModel.targetCanvasHeight = 126
            viewModel.pushUndo()
            viewModel.document.areGuidesVisible.toggle()
            viewModel.pushUndo()
            viewModel.document.areRulersVisible.toggle()
            viewModel.undo()
            let before = try atomicSnapshot(viewModel)

            viewModel.resizeCanvas(to: CGSize(width: 60, height: 40), anchor: .center)

            #expect(try atomicSnapshot(viewModel) == before)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
        }
    }

    @Test func invalidCanvasTargetsRejectAtCommandBoundaryWithCompleteAtomicSnapshot() throws {
        let invalidTargets = [
            CGSize(width: 100, height: 80),
            CGSize(width: 7, height: 80),
            CGSize(width: 12_001, height: 80),
            CGSize(width: 0, height: 80),
            CGSize(width: -1, height: 80),
            CGSize(width: CGFloat.nan, height: 80),
            CGSize(width: CGFloat.infinity, height: 80),
            CGSize(width: 100, height: 7),
            CGSize(width: 100, height: 12_001),
            CGSize(width: 100, height: 0),
            CGSize(width: 100, height: -1),
            CGSize(width: 100, height: CGFloat.nan),
            CGSize(width: 100, height: CGFloat.infinity)
        ]
        for target in invalidTargets {
            let viewModel = makeViewModel()
            let slice = ImageEditorSlice(
                name: "Atomic target",
                frame: CGRect(x: 20, y: 20, width: 40, height: 20),
                exportPresets: deliveryPresets()
            )
            viewModel.document.slices = [slice]
            viewModel.exportSettings.scope = .slice
            viewModel.exportSettings.sliceID = slice.id
            viewModel.isSlicesPanelVisible = true
            viewModel.isHotspotsPanelVisible = true
            viewModel.canvasOffset = CGSize(width: 7, height: -3)
            viewModel.selectedCanvasAnchor = .topRight
            viewModel.targetImageWidth = 123
            viewModel.targetImageHeight = 124
            viewModel.targetCanvasWidth = 125
            viewModel.targetCanvasHeight = 126
            viewModel.pushUndo()
            viewModel.document.areGuidesVisible.toggle()
            viewModel.pushUndo()
            viewModel.document.areRulersVisible.toggle()
            viewModel.undo()
            let before = try atomicSnapshot(viewModel)

            viewModel.resizeCanvas(to: target, anchor: .center)

            #expect(try atomicSnapshot(viewModel) == before)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
        }
    }

    @Test func invalidSourceCanvasRejectsBeforeUndo() throws {
        let invalidSizes = [
            CGSize(width: 0, height: 80),
            CGSize(width: -1, height: 80),
            CGSize(width: CGFloat.nan, height: 80),
            CGSize(width: CGFloat.infinity, height: 80),
            CGSize(width: 100, height: 0),
            CGSize(width: 100, height: -1),
            CGSize(width: 100, height: CGFloat.nan),
            CGSize(width: 100, height: CGFloat.infinity)
        ]
        for size in invalidSizes {
            let viewModel = makeViewModel()
            viewModel.document.canvasSize = size
            viewModel.document.slices = [ImageEditorSlice(name: "Slice", frame: CGRect(x: 10, y: 10, width: 20, height: 20))]
            let before = try atomicSnapshot(viewModel)
            viewModel.resizeCanvas(to: CGSize(width: 60, height: 40), anchor: .center)
            #expect(try atomicSnapshot(viewModel) == before)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
        }
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "slice-canvas-size.png",
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

    private func sliceWithPresets(_ presets: [ImageEditorSliceExportPreset]) -> ImageEditorSlice {
        ImageEditorSlice(
            name: "Preset validation",
            frame: CGRect(x: 20, y: 20, width: 40, height: 20),
            exportPresets: presets
        )
    }

    private func documentData(_ document: ImageEditorDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return try encoder.encode(ImageEditorProjectDocument(document: document))
    }

    private func atomicSnapshot(_ viewModel: ImageEditorViewModel) throws -> AtomicSnapshot {
        AtomicSnapshot(
            document: try documentData(viewModel.document),
            undo: try viewModel.undoStack.map(documentData),
            redo: try viewModel.redoStack.map(documentData),
            exportSettings: viewModel.exportSettings,
            selectedHotspotID: viewModel.selectedHotspotID,
            isNavigatorPanelVisible: viewModel.isNavigatorPanelVisible,
            isHistoryPanelVisible: viewModel.isHistoryPanelVisible,
            isLayersPanelVisible: viewModel.isLayersPanelVisible,
            isPropertiesPanelVisible: viewModel.isPropertiesPanelVisible,
            isSlicesPanelVisible: viewModel.isSlicesPanelVisible,
            isHotspotsPanelVisible: viewModel.isHotspotsPanelVisible,
            canvasOffset: viewModel.canvasOffset,
            selectedCanvasAnchor: viewModel.selectedCanvasAnchor.rawValue,
            targetImageWidth: viewModel.targetImageWidth,
            targetImageHeight: viewModel.targetImageHeight,
            targetCanvasWidth: viewModel.targetCanvasWidth,
            targetCanvasHeight: viewModel.targetCanvasHeight
        )
    }

    private struct AtomicSnapshot: Equatable {
        let document: Data
        let undo: [Data]
        let redo: [Data]
        let exportSettings: ImageEditorExportSettings
        let selectedHotspotID: UUID?
        let isNavigatorPanelVisible: Bool
        let isHistoryPanelVisible: Bool
        let isLayersPanelVisible: Bool
        let isPropertiesPanelVisible: Bool
        let isSlicesPanelVisible: Bool
        let isHotspotsPanelVisible: Bool
        let canvasOffset: CGSize
        let selectedCanvasAnchor: String
        let targetImageWidth: Double
        let targetImageHeight: Double
        let targetCanvasWidth: Double
        let targetCanvasHeight: Double
    }
}
