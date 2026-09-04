import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSliceRevealAllTransformTests {
    @Test func revealAllOffsetsSlicesForRightTopLeftAndFourDirectionExpansion() {
        let cases: [(CGRect, CGRect, CGSize, CGRect)] = [
            (CGRect(x: 90, y: 20, width: 30, height: 20), CGRect(x: 12, y: 14, width: 20, height: 10), CGSize(width: 120, height: 80), CGRect(x: 12, y: 14, width: 20, height: 10)),
            (CGRect(x: 30, y: 70, width: 20, height: 20), CGRect(x: 12, y: 14, width: 20, height: 10), CGSize(width: 100, height: 90), CGRect(x: 12, y: 14, width: 20, height: 10)),
            (CGRect(x: -10, y: 20, width: 20, height: 20), CGRect(x: 12, y: 14, width: 20, height: 10), CGSize(width: 110, height: 80), CGRect(x: 22, y: 14, width: 20, height: 10)),
            (CGRect(x: -10, y: -6, width: 130, height: 96), CGRect(x: 12, y: 14, width: 20, height: 10), CGSize(width: 130, height: 96), CGRect(x: 22, y: 20, width: 20, height: 10))
        ]

        for (layerFrame, sliceFrame, canvasSize, expectedFrame) in cases {
            let viewModel = makeViewModel(revealLayerFrame: layerFrame)
            let slice = ImageEditorSlice(name: "Directional", frame: sliceFrame)
            viewModel.document.slices = [slice]

            viewModel.revealAllLayers()

            #expect(viewModel.document.canvasSize == canvasSize)
            #expect(viewModel.document.slices.map(\.id) == [slice.id])
            #expect(viewModel.document.slices.first?.frame == expectedFrame)
        }
    }

    @Test func revealAllRestoresHistoricalOutOfBoundsSlicesAndPreservesMetadata() {
        let viewModel = makeViewModel(revealLayerFrame: CGRect(x: -20, y: 10, width: 20, height: 20))
        let presets = deliveryPresets(width: 80)
        let restored = ImageEditorSlice(
            name: "  Historical hero  ",
            frame: CGRect(x: -20, y: 16, width: 60, height: 20),
            exportPresets: presets
        )
        var explicitEmpty = ImageEditorSlice(name: "Explicit empty", frame: CGRect(x: 40, y: 20, width: 10, height: 10))
        explicitEmpty.exportPresets = []
        let legacyNil = ImageEditorSlice(name: "Legacy nil", frame: CGRect(x: 60, y: 20, width: 10, height: 10))
        viewModel.document.slices = [restored, explicitEmpty, legacyNil]

        viewModel.revealAllLayers()

        #expect(viewModel.document.slices.map(\.id) == [restored.id, explicitEmpty.id, legacyNil.id])
        #expect(viewModel.document.slices.map(\.name) == ["  Historical hero  ", "Explicit empty", "Legacy nil"])
        #expect(viewModel.document.slices.map(\.frame) == [
            CGRect(x: 0, y: 16, width: 60, height: 20),
            CGRect(x: 60, y: 20, width: 10, height: 10),
            CGRect(x: 80, y: 20, width: 10, height: 10)
        ])
        #expect(viewModel.document.slices[0].exportPresets == presets)
        #expect(viewModel.document.slices[1].exportPresets != nil)
        #expect(viewModel.document.slices[1].exportPresets?.isEmpty == true)
        #expect(viewModel.document.slices[2].exportPresets == nil)
    }

    @Test func revealAllAcceptsPresetBoundaryButRejectsInvalidSourceAndTargetPresetsAtomically() throws {
        let validBoundary = makeViewModel(revealLayerFrame: CGRect(x: -20, y: 10, width: 20, height: 20))
        validBoundary.document.slices = [ImageEditorSlice(
            name: "Source 4x boundary",
            frame: CGRect(x: -20, y: 16, width: 60, height: 20),
            exportPresets: deliveryPresets(width: 160)
        )]
        validBoundary.revealAllLayers()
        #expect(validBoundary.document.slices.first?.frame == CGRect(x: 0, y: 16, width: 60, height: 20))

        let rejectedSlices = [
            ImageEditorSlice(
                name: "Source invalid",
                frame: CGRect(x: -20, y: 16, width: 60, height: 20),
                exportPresets: deliveryPresets(width: 161)
            ),
            ImageEditorSlice(
                name: "Target invalid after restoration",
                frame: CGRect(x: -20, y: 16, width: 60, height: 20),
                exportPresets: deliveryPresets(width: 10)
            )
        ]
        for slice in rejectedSlices {
            let viewModel = makeAtomicViewModel(slice: slice)
            let before = try atomicSnapshot(viewModel)

            viewModel.revealAllLayers()

            #expect(try atomicSnapshot(viewModel) == before)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
        }
    }

    @Test func invalidOrOutsideSourceSliceRejectsRevealAllAtomically() throws {
        for frame in [
            CGRect(x: CGFloat.nan, y: 10, width: 20, height: 10),
            CGRect(x: 150, y: 10, width: 20, height: 10)
        ] {
            let viewModel = makeAtomicViewModel(slice: ImageEditorSlice(name: "Rejected", frame: frame))
            let before = try atomicSnapshot(viewModel)

            viewModel.revealAllLayers()

            #expect(try atomicSnapshot(viewModel) == before)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
        }
    }

    @Test func slicesNeverParticipateInRevealBoundsOrAvailability() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "slice-only-reveal.png",
            image: NSImage.transparent(size: CGSize(width: 100, height: 80))
        ) { _ in }
        let outside = ImageEditorSlice(name: "Slice does not reveal", frame: CGRect(x: -30, y: 10, width: 20, height: 10))
        viewModel.document.slices = [outside]
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = outside.id
        viewModel.exportSettings.filenameSuffix = "slice-only"
        viewModel.isNavigatorPanelVisible = true
        viewModel.isHistoryPanelVisible = true
        viewModel.isLayersPanelVisible = false
        viewModel.isPropertiesPanelVisible = true
        viewModel.isSlicesPanelVisible = true
        viewModel.isHotspotsPanelVisible = true
        viewModel.canvasOffset = CGSize(width: 8, height: -5)
        viewModel.selectedCanvasAnchor = .topRight
        viewModel.targetImageWidth = 222
        viewModel.targetImageHeight = 333
        viewModel.targetCanvasWidth = 444
        viewModel.targetCanvasHeight = 555
        viewModel.pushUndo()
        viewModel.document.areGuidesVisible.toggle()
        viewModel.pushUndo()
        viewModel.document.areRulersVisible.toggle()
        viewModel.undo()
        #expect(!viewModel.undoStack.isEmpty)
        #expect(!viewModel.redoStack.isEmpty)
        let before = try atomicSnapshot(viewModel)

        #expect(!viewModel.canRevealAllLayers)
        viewModel.revealAllLayers()
        #expect(try atomicSnapshot(viewModel) == before)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.revealAllNoHiddenPixels"))
    }

    @Test func revealAllRepairsEverySliceScopeStateWithoutChangingNonSliceSettings() {
        let first = ImageEditorSlice(
            name: "First",
            frame: CGRect(x: 10, y: 20, width: 20, height: 10),
            exportPresets: deliveryPresets(width: 40)
        )
        let second = ImageEditorSlice(
            name: "Second",
            frame: CGRect(x: 40, y: 20, width: 10, height: 10),
            exportPresets: [ImageEditorSliceExportPreset(suffix: "-second", format: .jpeg, constraint: .scale, value: 3)]
        )
        let cases: [(UUID?, UUID, ImageEditorExportFormat, Double, String)] = [
            (second.id, second.id, .jpeg, 3, "-second"),
            (nil, first.id, .png, 2, "-width"),
            (UUID(), first.id, .png, 2, "-width")
        ]
        let fourDirectionReveal = CGRect(x: -10, y: -6, width: 130, height: 96)
        let expectedFrames = [
            CGRect(x: 20, y: 26, width: 20, height: 10),
            CGRect(x: 50, y: 26, width: 10, height: 10)
        ]
        for (selectedID, expectedID, format, scale, suffix) in cases {
            let viewModel = makeViewModel(revealLayerFrame: fourDirectionReveal)
            viewModel.document.slices = [first, second]
            viewModel.exportSettings.scope = .slice
            viewModel.exportSettings.sliceID = selectedID
            viewModel.exportSettings.filenameSuffix = "stale"
            viewModel.revealAllLayers()
            #expect(viewModel.document.slices.map(\.frame) == expectedFrames)
            #expect(viewModel.exportSettings.sliceID == expectedID)
            #expect(viewModel.exportSettings.format == format)
            #expect(viewModel.exportSettings.scale == scale)
            #expect(viewModel.exportSettings.filenameSuffix == suffix)
        }

        let empty = makeViewModel(revealLayerFrame: fourDirectionReveal)
        empty.exportSettings.scope = .slice
        empty.exportSettings.sliceID = UUID()
        empty.exportSettings.filenameSuffix = "stale"
        empty.revealAllLayers()
        #expect(empty.document.slices.isEmpty)
        #expect(empty.exportSettings.scope == .composited)
        #expect(empty.exportSettings.sliceID == nil)
        #expect(empty.exportSettings.filenameSuffix.isEmpty)

        let noPreset = makeViewModel(revealLayerFrame: fourDirectionReveal)
        let noPresetSlice = ImageEditorSlice(name: "No preset", frame: CGRect(x: 10, y: 20, width: 20, height: 10))
        noPreset.document.slices = [noPresetSlice]
        noPreset.exportSettings.scope = .slice
        noPreset.exportSettings.sliceID = noPresetSlice.id
        noPreset.exportSettings.format = .jpeg
        noPreset.exportSettings.scale = 3
        noPreset.exportSettings.batchScales = [1, 2]
        noPreset.exportSettings.filenameSuffix = "stale"
        noPreset.revealAllLayers()
        #expect(noPreset.document.slices.first?.frame == CGRect(x: 20, y: 26, width: 20, height: 10))
        #expect(noPreset.exportSettings.format == .jpeg)
        #expect(noPreset.exportSettings.scale == 3)
        #expect(noPreset.exportSettings.batchScales == [1, 2])
        #expect(noPreset.exportSettings.filenameSuffix.isEmpty)

        let nonSlice = makeViewModel(revealLayerFrame: fourDirectionReveal)
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
        nonSlice.revealAllLayers()
        #expect(nonSlice.document.slices.first?.frame == CGRect(x: 20, y: 26, width: 20, height: 10))
        #expect(nonSlice.exportSettings == settings)
    }

    @Test func revealAllIsOneTransactionAndUndoRedoRestoresRealPresetProjection() throws {
        let viewModel = makeViewModel(revealLayerFrame: CGRect(x: -10, y: 10, width: 20, height: 20))
        let slice = ImageEditorSlice(
            name: "Clipped opposite edge",
            frame: CGRect(x: 95, y: 20, width: 20, height: 10),
            exportPresets: deliveryPresets(width: 20)
        )
        viewModel.document.slices = [slice]
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = slice.id
        viewModel.syncExportSettingsForCurrentSliceScope()
        #expect(viewModel.exportSettings.scale == 1)
        viewModel.pushUndo()
        viewModel.document.areGuidesVisible.toggle()
        viewModel.pushUndo()
        viewModel.document.areRulersVisible.toggle()
        viewModel.undo()
        let before = try documentData(viewModel.document)
        let undoCount = viewModel.undoStack.count
        let historyCount = viewModel.document.history.count
        #expect(!viewModel.redoStack.isEmpty)

        viewModel.revealAllLayers()

        let after = try documentData(viewModel.document)
        #expect(viewModel.document.slices.first?.frame == CGRect(x: 105, y: 20, width: 5, height: 10))
        #expect(viewModel.exportSettings.scale == 4)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(viewModel.redoStack.isEmpty)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.revealAll"))

        viewModel.undo()
        #expect(try documentData(viewModel.document) == before)
        #expect(viewModel.exportSettings.scale == 1)
        viewModel.redo()
        #expect(try documentData(viewModel.document) == after)
        #expect(viewModel.exportSettings.scale == 4)
    }

    private func makeViewModel(revealLayerFrame: CGRect) -> ImageEditorViewModel {
        let viewModel = ImageEditorViewModel(
            sourceName: "slice-reveal.png",
            image: NSImage.transparent(size: CGSize(width: 100, height: 80))
        ) { _ in }
        var revealLayer = ImageEditorLayer.blank(name: "Reveal bounds", size: revealLayerFrame.size)
        revealLayer.image = NSImage.opaqueMask(size: revealLayerFrame.size)
        revealLayer.frame = revealLayerFrame
        viewModel.document.layers.append(revealLayer)
        return viewModel
    }

    private func makeAtomicViewModel(slice: ImageEditorSlice) -> ImageEditorViewModel {
        let viewModel = makeViewModel(revealLayerFrame: CGRect(x: -20, y: 10, width: 20, height: 20))
        viewModel.document.slices = [slice]
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = slice.id
        let hotspotID = UUID()
        viewModel.document.hotspots = [ImageEditorHotspot(
            id: hotspotID,
            name: "Stable hotspot",
            frame: CGRect(x: 10, y: 10, width: 10, height: 10)
        )]
        viewModel.selectedHotspotID = hotspotID
        viewModel.isNavigatorPanelVisible = true
        viewModel.isHistoryPanelVisible = true
        viewModel.isLayersPanelVisible = false
        viewModel.isPropertiesPanelVisible = true
        viewModel.isSlicesPanelVisible = true
        viewModel.isHotspotsPanelVisible = true
        viewModel.canvasOffset = CGSize(width: 7, height: -3)
        viewModel.selectedCanvasAnchor = .bottomRight
        viewModel.targetImageWidth = 222
        viewModel.targetImageHeight = 333
        viewModel.targetCanvasWidth = 321
        viewModel.targetCanvasHeight = 123
        viewModel.pushUndo()
        viewModel.document.areGuidesVisible.toggle()
        viewModel.pushUndo()
        viewModel.document.areRulersVisible.toggle()
        viewModel.undo()
        return viewModel
    }

    private func deliveryPresets(width: Double) -> [ImageEditorSliceExportPreset] {
        [
            ImageEditorSliceExportPreset(suffix: "-width", format: .png, constraint: .width, value: width),
            ImageEditorSliceExportPreset(suffix: "-height", format: .jpeg, constraint: .height, value: 20),
            ImageEditorSliceExportPreset(suffix: "-vector", format: .pdf, constraint: .scale, value: 1)
        ]
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
