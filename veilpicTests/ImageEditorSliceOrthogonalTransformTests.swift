import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSliceOrthogonalTransformTests {
    private let canvasSize = CGSize(width: 100, height: 80)
    private let primaryID = UUID(uuidString: "31111111-1111-1111-1111-111111111111")!

    @Test
    func modelTransformsFiveWaysFromCompleteStandardizedFrameAndPreservesMetadata() throws {
        let sourcePresets = [
            ImageEditorSliceExportPreset(suffix: "", format: .png, constraint: .width, value: 26),
            ImageEditorSliceExportPreset(suffix: "-height", format: .jpeg, constraint: .height, value: 10),
            ImageEditorSliceExportPreset(suffix: "-half", format: .pdf, constraint: .scale, value: 0.5)
        ]
        let source = ImageEditorSlice(
            id: primaryID,
            name: "  Delivery region  ",
            frame: CGRect(x: 30.75, y: 24.25, width: -12.5, height: -8.5),
            exportPresets: sourcePresets
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
            #expect(transformed.exportPresets == sourcePresets)
        }

        var explicitEmpty = ImageEditorSlice(name: "Explicit empty", frame: CGRect(x: 10, y: 10, width: 12, height: 8))
        explicitEmpty.exportPresets = []
        let transformedEmpty = try explicitEmpty.transformedForOrthogonalCanvas(.clockwise90, sourceCanvasSize: canvasSize)
        #expect(transformedEmpty.exportPresets != nil)
        #expect(transformedEmpty.exportPresets?.isEmpty == true)
        let legacyNil = ImageEditorSlice(name: "Legacy", frame: CGRect(x: 10, y: 10, width: 12, height: 8))
        #expect(try legacyNil.transformedForOrthogonalCanvas(.clockwise90, sourceCanvasSize: canvasSize).exportPresets == nil)
    }

    @Test
    func modelAcceptsPartialSourceAndValidatesSourceAndTargetPresetBoundaries() throws {
        let partialPresets = [
            ImageEditorSliceExportPreset(suffix: "", format: .png, constraint: .width, value: 42),
            ImageEditorSliceExportPreset(suffix: "-height", format: .jpeg, constraint: .height, value: 21),
            ImageEditorSliceExportPreset(suffix: "-vector", format: .pdf, constraint: .scale, value: 1)
        ]
        let partial = ImageEditorSlice(
            name: "Historical partial",
            frame: CGRect(x: -10.2, y: 10.4, width: 30.4, height: 20.2),
            exportPresets: partialPresets
        )
        let transformed = try partial.transformedForOrthogonalCanvas(
            .clockwise90,
            sourceCanvasSize: canvasSize
        )
        #expect(transformed.frame == CGRect(x: 49, y: 0, width: 21, height: 21))
        #expect(transformed.exportPresets == partialPresets)

        let validBoundary = ImageEditorSlice(
            name: "Target 4x boundary",
            frame: CGRect(x: 10, y: 20, width: 40, height: 20),
            exportPresets: presets(width: 80)
        )
        #expect(try validBoundary.transformedForOrthogonalCanvas(
            .clockwise90,
            sourceCanvasSize: canvasSize
        ).frame == CGRect(x: 40, y: 10, width: 20, height: 40))

        for invalidWidth in [9.0, 81.0] {
            let invalid = ImageEditorSlice(
                name: "Invalid preset",
                frame: CGRect(x: 10, y: 20, width: 40, height: 20),
                exportPresets: presets(width: invalidWidth)
            )
            #expect(throws: (any Error).self) {
                try invalid.transformedForOrthogonalCanvas(.clockwise90, sourceCanvasSize: canvasSize)
            }
        }

        let targetInvalidPartial = ImageEditorSlice(
            name: "Partial target denominator",
            frame: CGRect(x: -10, y: 10, width: 50, height: 10),
            exportPresets: presets(width: 41)
        )
        #expect(abs((targetInvalidPartial.exportPresets?[0].resolvedScale(for: CGRect(x: 0, y: 10, width: 40, height: 10)) ?? 0) - 1.025) < 0.000_001)
        #expect(targetInvalidPartial.exportPresets?[0].resolvedScale(for: CGRect(x: 60, y: 0, width: 10, height: 40)) == nil)
        #expect(throws: (any Error).self) {
            try targetInvalidPartial.transformedForOrthogonalCanvas(.clockwise90, sourceCanvasSize: canvasSize)
        }

        let isolatedInvalidSlices = [
            ImageEditorSlice(
                name: "Height source invalid",
                frame: CGRect(x: 10, y: 20, width: 40, height: 20),
                exportPresets: [ImageEditorSliceExportPreset(suffix: "-height", format: .png, constraint: .height, value: 4)]
            ),
            ImageEditorSlice(
                name: "Scale below minimum",
                frame: CGRect(x: 10, y: 20, width: 40, height: 20),
                exportPresets: [ImageEditorSliceExportPreset(suffix: "-small", format: .png, constraint: .scale, value: 0.2)]
            ),
            ImageEditorSlice(
                name: "Scale above maximum",
                frame: CGRect(x: 10, y: 20, width: 40, height: 20),
                exportPresets: [ImageEditorSliceExportPreset(suffix: "-large", format: .png, constraint: .scale, value: 4.1)]
            ),
            ImageEditorSlice(name: "Zero height", frame: CGRect(x: 10, y: 20, width: 40, height: 0))
        ]
        for invalid in isolatedInvalidSlices {
            #expect(throws: (any Error).self) {
                try invalid.transformedForOrthogonalCanvas(.clockwise90, sourceCanvasSize: canvasSize)
            }
        }

        let heightTargetPreset = ImageEditorSliceExportPreset(
            suffix: "-height-target",
            format: .png,
            constraint: .height,
            value: 9
        )
        #expect(abs((heightTargetPreset.resolvedScale(for: CGRect(x: 10, y: 20, width: 40, height: 20)) ?? 0) - 0.45) < 0.000_001)
        #expect(heightTargetPreset.resolvedScale(for: CGRect(x: 40, y: 10, width: 20, height: 40)) == nil)
        let heightTargetInvalid = ImageEditorSlice(
            name: "Height target invalid",
            frame: CGRect(x: 10, y: 20, width: 40, height: 20),
            exportPresets: [heightTargetPreset]
        )
        #expect(throws: (any Error).self) {
            try heightTargetInvalid.transformedForOrthogonalCanvas(.clockwise90, sourceCanvasSize: canvasSize)
        }

        let outside = ImageEditorSlice(name: "Outside", frame: CGRect(x: 110, y: 10, width: 20, height: 10))
        #expect(throws: (any Error).self) {
            try outside.transformedForOrthogonalCanvas(.clockwise90, sourceCanvasSize: canvasSize)
        }
    }

    @Test
    func directCommandsTransformSlicesAndHotspotAsOneUndoableTransaction() throws {
        let expectations: [(ImageEditorCanvasOrthogonalTransform, CGSize, CGRect, CGRect, Double)] = [
            (.clockwise90, CGSize(width: 80, height: 100), CGRect(x: 40, y: 10, width: 20, height: 40), CGRect(x: 55, y: 18, width: 10, height: 13), 2),
            (.counterclockwise90, CGSize(width: 80, height: 100), CGRect(x: 20, y: 50, width: 20, height: 40), CGRect(x: 15, y: 69, width: 10, height: 13), 2),
            (.rotate180, canvasSize, CGRect(x: 50, y: 40, width: 40, height: 20), CGRect(x: 69, y: 55, width: 13, height: 10), 1),
            (.flipHorizontal, canvasSize, CGRect(x: 50, y: 20, width: 40, height: 20), CGRect(x: 69, y: 15, width: 13, height: 10), 1),
            (.flipVertical, canvasSize, CGRect(x: 10, y: 40, width: 40, height: 20), CGRect(x: 18, y: 55, width: 13, height: 10), 1)
        ]

        for (transform, expectedSize, expectedSlice, expectedHotspot, expectedScale) in expectations {
            let viewModel = makeViewModel()
            viewModel.exportSettings.scope = .slice
            viewModel.exportSettings.sliceID = primaryID
            viewModel.syncExportSettingsForCurrentSliceScope()
            #expect(viewModel.exportSettings.scale == 1)
            apply(.flipHorizontal, to: viewModel)
            viewModel.undo()
            let before = try documentData(viewModel.document)
            let undoCount = viewModel.undoStack.count
            let historyCount = viewModel.document.history.count
            #expect(!viewModel.redoStack.isEmpty)

            apply(transform, to: viewModel)

            #expect(viewModel.document.canvasSize == expectedSize)
            #expect(viewModel.document.slices.first?.frame == expectedSlice)
            #expect(viewModel.document.slices.first?.id == primaryID)
            #expect(viewModel.document.slices.first?.name == "  Delivery region  ")
            #expect(viewModel.document.slices.first?.exportPresets == presets(width: 40))
            #expect(viewModel.document.hotspots.first?.frame == expectedHotspot)
            #expect(viewModel.exportSettings.scope == .slice)
            #expect(viewModel.exportSettings.sliceID == primaryID)
            #expect(viewModel.exportSettings.scale == expectedScale)
            #expect(viewModel.undoStack.count == undoCount + 1)
            #expect(viewModel.redoStack.isEmpty)
            #expect(viewModel.document.history.count == historyCount + 1)
            #expect(viewModel.document.history.last?.title == historyTitle(for: transform))
            #expect(viewModel.targetImageWidth == Double(expectedSize.width))
            #expect(viewModel.targetImageHeight == Double(expectedSize.height))
            #expect(viewModel.targetCanvasWidth == Double(expectedSize.width))
            #expect(viewModel.targetCanvasHeight == Double(expectedSize.height))
            let after = try documentData(viewModel.document)

            viewModel.undo()
            #expect(try documentData(viewModel.document) == before)
            #expect(viewModel.exportSettings.scale == 1)
            #expect(viewModel.targetImageWidth == Double(canvasSize.width))
            #expect(viewModel.targetImageHeight == Double(canvasSize.height))
            #expect(viewModel.targetCanvasWidth == Double(canvasSize.width))
            #expect(viewModel.targetCanvasHeight == Double(canvasSize.height))
            viewModel.redo()
            #expect(try documentData(viewModel.document) == after)
            #expect(viewModel.exportSettings.scale == expectedScale)
            #expect(viewModel.targetImageWidth == Double(expectedSize.width))
            #expect(viewModel.targetImageHeight == Double(expectedSize.height))
            #expect(viewModel.targetCanvasWidth == Double(expectedSize.width))
            #expect(viewModel.targetCanvasHeight == Double(expectedSize.height))
        }
    }

    @Test
    func directCommandRepairsSliceScopeMatrixAndLeavesNonSliceSettingsExact() {
        let first = ImageEditorSlice(
            id: primaryID,
            name: "First",
            frame: CGRect(x: 10, y: 20, width: 40, height: 20),
            exportPresets: presets(width: 40)
        )
        let second = ImageEditorSlice(
            name: "Second",
            frame: CGRect(x: 55, y: 20, width: 20, height: 10),
            exportPresets: [ImageEditorSliceExportPreset(suffix: "-second", format: .jpeg, constraint: .scale, value: 3)]
        )
        for (selected, expected) in [(second.id as UUID?, second.id), (nil, first.id), (UUID(), first.id)] {
            let viewModel = makeViewModel()
            viewModel.document.slices = [first, second]
            viewModel.exportSettings.scope = .slice
            viewModel.exportSettings.sliceID = selected
            viewModel.exportSettings.filenameSuffix = "stale"
            viewModel.rotateClockwise()
            #expect(viewModel.document.slices.map(\.frame) == [
                CGRect(x: 40, y: 10, width: 20, height: 40),
                CGRect(x: 50, y: 55, width: 10, height: 20)
            ])
            #expect(viewModel.exportSettings.sliceID == expected)
            #expect(viewModel.exportSettings.scale == (expected == first.id ? 2 : 3))
            #expect(viewModel.exportSettings.filenameSuffix == (expected == first.id ? "-width" : "-second"))
        }

        let empty = makeViewModel()
        empty.document.slices = []
        empty.exportSettings.scope = .slice
        empty.exportSettings.sliceID = UUID()
        empty.exportSettings.filenameSuffix = "stale"
        empty.rotateClockwise()
        #expect(empty.exportSettings.scope == .composited)
        #expect(empty.exportSettings.sliceID == nil)
        #expect(empty.exportSettings.filenameSuffix.isEmpty)

        let noPreset = makeViewModel()
        var explicitEmpty = ImageEditorSlice(name: "No presets", frame: CGRect(x: 10, y: 20, width: 40, height: 20))
        explicitEmpty.exportPresets = []
        noPreset.document.slices = [explicitEmpty]
        noPreset.exportSettings = ImageEditorExportSettings(
            format: .jpeg,
            scope: .slice,
            sliceID: explicitEmpty.id,
            scale: 3,
            batchScales: [1, 2],
            namingRule: .sourceName,
            quality: 0.42,
            filenameSuffix: "stale",
            sliceConflictPolicy: .skipExisting
        )
        noPreset.rotateClockwise()
        #expect(noPreset.document.slices.first?.frame == CGRect(x: 40, y: 10, width: 20, height: 40))
        #expect(noPreset.document.slices.first?.exportPresets?.isEmpty == true)
        #expect(noPreset.exportSettings.format == .jpeg)
        #expect(noPreset.exportSettings.scale == 3)
        #expect(noPreset.exportSettings.batchScales == [1, 2])
        #expect(noPreset.exportSettings.namingRule == .sourceName)
        #expect(noPreset.exportSettings.quality == 0.42)
        #expect(noPreset.exportSettings.sliceConflictPolicy == .skipExisting)
        #expect(noPreset.exportSettings.filenameSuffix.isEmpty)

        let nonSlice = makeViewModel()
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
        nonSlice.rotateClockwise()
        #expect(nonSlice.document.slices.first?.frame == CGRect(x: 40, y: 10, width: 20, height: 40))
        #expect(nonSlice.exportSettings == settings)
    }

    @Test
    func invalidSliceGeometryOrPresetRejectsEveryCommandAtomically() throws {
        let mutations: [(ImageEditorViewModel) -> Void] = [
            { $0.document.canvasSize = CGSize(width: 0, height: 80) },
            { $0.document.canvasSize = CGSize(width: CGFloat.nan, height: 80) },
            { $0.document.slices[0].frame.origin.x = CGFloat.nan },
            { $0.document.slices[0].frame.size.height = CGFloat.infinity },
            { $0.document.slices[0].frame = CGRect(x: CGFloat.greatestFiniteMagnitude, y: 10, width: CGFloat.greatestFiniteMagnitude, height: 10) },
            { $0.document.slices[0].frame.size.width = 0 },
            { $0.document.slices[0].frame = CGRect(x: 100, y: 10, width: 10, height: 10) },
            { $0.document.slices[0].frame = CGRect(x: 120, y: 10, width: 10, height: 10) },
            { $0.document.slices[0].exportPresets = self.presets(width: 9) },
            { $0.document.slices[0].exportPresets = Array(repeating: self.presets(width: 40)[0], count: ImageEditorSlice.maximumExportPresetCount + 1) },
            { $0.document.slices[0].exportPresets = [ImageEditorSliceExportPreset(suffix: "bad-format", format: .webp, constraint: .scale, value: 1)] },
            { $0.document.slices[0].exportPresets = [ImageEditorSliceExportPreset(suffix: "bad-value", format: .png, constraint: .scale, value: .nan)] },
            { $0.document.hotspots[0].frame.origin.x = CGFloat.nan },
            { $0.document.hotspots[0].frame = CGRect(x: 95, y: 10, width: 10, height: 10) },
            { $0.document.layers[0].frame.origin.x = CGFloat.nan }
        ]

        for transform in ImageEditorCanvasOrthogonalTransform.allCases {
            for mutate in mutations {
                let viewModel = makeAtomicViewModel()
                mutate(viewModel)
                let before = try atomicSnapshot(viewModel)

                apply(transform, to: viewModel)

                #expect(try atomicSnapshot(viewModel) == before)
                #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
            }
        }

        for transform in [ImageEditorCanvasOrthogonalTransform.clockwise90, .counterclockwise90] {
            let viewModel = makeAtomicViewModel()
            viewModel.document.slices[0].exportPresets = presets(width: 81)
            let before = try atomicSnapshot(viewModel)
            apply(transform, to: viewModel)
            #expect(try atomicSnapshot(viewModel) == before)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
        }
    }

    private func makeViewModel() -> ImageEditorViewModel {
        let viewModel = ImageEditorViewModel(
            sourceName: "slice-orthogonal.png",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        viewModel.document.slices = [ImageEditorSlice(
            id: primaryID,
            name: "  Delivery region  ",
            frame: CGRect(x: 10, y: 20, width: 40, height: 20),
            exportPresets: presets(width: 40)
        )]
        viewModel.document.hotspots = [ImageEditorHotspot(
            name: "Hotspot peer",
            frame: CGRect(x: 30.75, y: 24.25, width: -12.5, height: -8.5),
            url: "peer://stable"
        )]
        return viewModel
    }

    private func makeAtomicViewModel() -> ImageEditorViewModel {
        let viewModel = makeViewModel()
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = primaryID
        viewModel.selectedHotspotID = viewModel.document.hotspots.first?.id
        viewModel.isNavigatorPanelVisible = true
        viewModel.isHistoryPanelVisible = false
        viewModel.isLayersPanelVisible = true
        viewModel.isPropertiesPanelVisible = false
        viewModel.isSlicesPanelVisible = true
        viewModel.isHotspotsPanelVisible = true
        viewModel.canvasOffset = CGSize(width: 13, height: -7)
        viewModel.selectedCanvasAnchor = .bottomRight
        viewModel.targetImageWidth = 321
        viewModel.targetImageHeight = 654
        viewModel.targetCanvasWidth = 987
        viewModel.targetCanvasHeight = 456
        viewModel.pushUndo()
        viewModel.document.areGuidesVisible.toggle()
        viewModel.pushUndo()
        viewModel.document.areRulersVisible.toggle()
        viewModel.undo()
        return viewModel
    }

    private func apply(_ transform: ImageEditorCanvasOrthogonalTransform, to viewModel: ImageEditorViewModel) {
        switch transform {
        case .clockwise90: viewModel.rotateClockwise()
        case .counterclockwise90: viewModel.rotateCounterclockwise()
        case .rotate180: viewModel.rotate180()
        case .flipHorizontal: viewModel.flipHorizontal()
        case .flipVertical: viewModel.flipVertical()
        }
    }

    private func presets(width: Double) -> [ImageEditorSliceExportPreset] {
        [ImageEditorSliceExportPreset(suffix: "-width", format: .png, constraint: .width, value: width)]
    }

    private func historyTitle(for transform: ImageEditorCanvasOrthogonalTransform) -> String {
        switch transform {
        case .clockwise90: L10n.text("imageEditor.history.rotateClockwise")
        case .counterclockwise90: L10n.text("imageEditor.history.rotateCounterclockwise")
        case .rotate180: L10n.text("imageEditor.history.rotate180")
        case .flipHorizontal: L10n.text("imageEditor.history.flipHorizontal")
        case .flipVertical: L10n.text("imageEditor.history.flipVertical")
        }
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
            navigator: viewModel.isNavigatorPanelVisible,
            history: viewModel.isHistoryPanelVisible,
            layers: viewModel.isLayersPanelVisible,
            properties: viewModel.isPropertiesPanelVisible,
            slices: viewModel.isSlicesPanelVisible,
            hotspots: viewModel.isHotspotsPanelVisible,
            canvasOffset: viewModel.canvasOffset,
            anchor: viewModel.selectedCanvasAnchor.rawValue,
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
        let navigator: Bool
        let history: Bool
        let layers: Bool
        let properties: Bool
        let slices: Bool
        let hotspots: Bool
        let canvasOffset: CGSize
        let anchor: String
        let targetImageWidth: Double
        let targetImageHeight: Double
        let targetCanvasWidth: Double
        let targetCanvasHeight: Double
    }
}
