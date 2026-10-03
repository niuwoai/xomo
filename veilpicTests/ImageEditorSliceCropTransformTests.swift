import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSliceCropTransformTests {
    @Test func directCropKeepsClipsAndRemovesSlicesWithoutRewritingMetadata() throws {
        let ids = (0..<6).map { _ in UUID() }
        let presets = deliveryPresets()
        let viewModel = makeViewModel()
        var explicitEmpty = ImageEditorSlice(
            id: ids[4],
            name: "Explicit empty",
            frame: CGRect(x: 50, y: 45, width: 10, height: 10)
        )
        explicitEmpty.exportPresets = []
        viewModel.document.slices = [
            ImageEditorSlice(id: ids[0], name: "Kept", frame: CGRect(x: 30, y: 30, width: 20, height: 10), exportPresets: presets),
            ImageEditorSlice(id: ids[1], name: "Clipped", frame: CGRect(x: 10, y: 10, width: 20, height: 20)),
            ImageEditorSlice(id: ids[2], name: "Touching", frame: CGRect(x: 80, y: 20, width: 10, height: 10)),
            ImageEditorSlice(id: ids[3], name: "Outside", frame: CGRect(x: 90, y: 60, width: 5, height: 5)),
            explicitEmpty,
            ImageEditorSlice(id: ids[5], name: "Legacy nil", frame: CGRect(x: 65, y: 45, width: 15, height: 15))
        ]

        viewModel.crop(to: CGRect(x: 20, y: 20, width: 60, height: 40))

        #expect(viewModel.document.canvasSize == CGSize(width: 60, height: 40))
        #expect(viewModel.document.slices.map(\.id) == [ids[0], ids[1], ids[4], ids[5]])
        #expect(viewModel.document.slices.map(\.frame) == [
            CGRect(x: 10, y: 10, width: 20, height: 10),
            CGRect(x: 0, y: 0, width: 10, height: 10),
            CGRect(x: 30, y: 25, width: 10, height: 10),
            CGRect(x: 45, y: 25, width: 15, height: 15)
        ])
        #expect(viewModel.document.slices[0].name == "Kept")
        #expect(viewModel.document.slices[0].exportPresets == presets)
        #expect(viewModel.document.slices[2].exportPresets != nil)
        #expect(viewModel.document.slices[2].exportPresets?.isEmpty == true)
        #expect(viewModel.document.slices[3].exportPresets == nil)
    }

    @Test func cropCommitsIntegralBoundsThenUsesFloatingStandardizedSliceGeometry() {
        let viewModel = makeViewModel()
        viewModel.document.slices = [ImageEditorSlice(
            name: "Negative fractional",
            frame: CGRect(x: 40.4, y: 35.6, width: -20.2, height: -15.2)
        )]

        viewModel.crop(to: CGRect(x: 20.5, y: 20.5, width: 60, height: 40))

        #expect(viewModel.document.canvasSize == CGSize(width: 61, height: 41))
        #expect(viewModel.document.slices.first?.frame == CGRect(x: 0, y: 0, width: 21, height: 16))
    }

    @Test func cropValidatesSourceAndSurvivingTargetPresetsAndRemovedSources() throws {
        let sourceValidTargetInvalid = ImageEditorSlice(
            name: "Target invalid",
            frame: CGRect(x: 20, y: 0, width: 100, height: 80),
            exportPresets: [ImageEditorSliceExportPreset(
                suffix: "target",
                format: .png,
                constraint: .width,
                value: 241
            )]
        )
        let removedSourceInvalid = ImageEditorSlice(
            name: "Removed source invalid",
            frame: CGRect(x: 85, y: 20, width: 10, height: 10),
            exportPresets: [ImageEditorSliceExportPreset(
                suffix: "source",
                format: .jpeg,
                constraint: .width,
                value: 41
            )]
        )
        for slice in [sourceValidTargetInvalid, removedSourceInvalid] {
            let viewModel = makeViewModel()
            viewModel.document.slices = [slice]
            let before = try atomicSnapshot(viewModel)

            viewModel.crop(to: CGRect(x: 20, y: 20, width: 60, height: 40))

            #expect(try atomicSnapshot(viewModel) == before)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.cropInvalid"))
        }
    }

    @Test func invalidSliceRejectsCropWithCompleteAtomicSnapshot() throws {
        let viewModel = makeViewModel()
        let invalid = ImageEditorSlice(
            name: "NaN",
            frame: CGRect(x: CGFloat.nan, y: 10, width: 20, height: 20)
        )
        viewModel.document.slices = [invalid]
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = invalid.id
        viewModel.isSlicesPanelVisible = true
        viewModel.isHotspotsPanelVisible = true
        viewModel.canvasOffset = CGSize(width: 7, height: -3)
        viewModel.targetCanvasWidth = 321
        viewModel.targetCanvasHeight = 123
        viewModel.pushUndo()
        viewModel.document.areGuidesVisible.toggle()
        viewModel.pushUndo()
        viewModel.document.areRulersVisible.toggle()
        viewModel.undo()
        let before = try atomicSnapshot(viewModel)

        viewModel.crop(to: CGRect(x: 20, y: 20, width: 60, height: 40))

        #expect(try atomicSnapshot(viewModel) == before)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.cropInvalid"))
    }

    @Test func cropRepairsEverySliceScopeStateFromFinalSurvivors() {
        let first = ImageEditorSlice(
            name: "First",
            frame: CGRect(x: 30, y: 30, width: 20, height: 10),
            exportPresets: deliveryPresets()
        )
        let second = ImageEditorSlice(
            name: "Second",
            frame: CGRect(x: 55, y: 30, width: 10, height: 10),
            exportPresets: [ImageEditorSliceExportPreset(
                suffix: "-second",
                format: .jpeg,
                constraint: .scale,
                value: 3
            )]
        )
        let removed = ImageEditorSlice(name: "Removed", frame: CGRect(x: 85, y: 20, width: 10, height: 10))
        let cases: [(selectedID: UUID?, expectedID: UUID, format: ImageEditorExportFormat, scale: Double, suffix: String)] = [
            (second.id, second.id, .jpeg, 3, "-second"),
            (removed.id, first.id, .png, 2, "-width"),
            (nil, first.id, .png, 2, "-width"),
            (UUID(), first.id, .png, 2, "-width")
        ]
        for testCase in cases {
            let viewModel = makeViewModel()
            viewModel.document.slices = [first, second, removed]
            viewModel.exportSettings.scope = .slice
            viewModel.exportSettings.sliceID = testCase.selectedID
            viewModel.exportSettings.filenameSuffix = "stale"

            viewModel.crop(to: CGRect(x: 20, y: 20, width: 60, height: 40))

            #expect(viewModel.exportSettings.scope == .slice)
            #expect(viewModel.document.slices.map(\.id) == [first.id, second.id])
            #expect(viewModel.exportSettings.sliceID == testCase.expectedID)
            #expect(viewModel.exportSettings.format == testCase.format)
            #expect(viewModel.exportSettings.scale == testCase.scale)
            #expect(viewModel.exportSettings.filenameSuffix == testCase.suffix)
        }

        let empty = makeViewModel()
        empty.document.slices = [removed]
        empty.exportSettings.scope = .slice
        empty.exportSettings.sliceID = removed.id
        empty.exportSettings.filenameSuffix = "stale"
        empty.crop(to: CGRect(x: 20, y: 20, width: 60, height: 40))
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
        nonSlice.crop(to: CGRect(x: 20, y: 20, width: 60, height: 40))
        #expect(nonSlice.exportSettings == settings)
    }

    @Test func cropWithoutPresetOnlyClearsSuffix() {
        let viewModel = makeViewModel()
        let slice = ImageEditorSlice(name: "No preset", frame: CGRect(x: 30, y: 30, width: 20, height: 10))
        viewModel.document.slices = [slice]
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = slice.id
        viewModel.exportSettings.format = .jpeg
        viewModel.exportSettings.scale = 3
        viewModel.exportSettings.batchScales = [1, 2]
        viewModel.exportSettings.filenameSuffix = "stale"

        viewModel.crop(to: CGRect(x: 20, y: 20, width: 60, height: 40))

        #expect(viewModel.exportSettings.scope == .slice)
        #expect(viewModel.exportSettings.sliceID == slice.id)
        #expect(viewModel.exportSettings.format == .jpeg)
        #expect(viewModel.exportSettings.scale == 3)
        #expect(viewModel.exportSettings.batchScales == [1, 2])
        #expect(viewModel.exportSettings.filenameSuffix.isEmpty)
    }

    @Test func cropIsOneTransactionAndUndoRedoRestoresPresetProjection() throws {
        let viewModel = makeViewModel()
        let slice = ImageEditorSlice(
            name: "Hero",
            frame: CGRect(x: 10, y: 30, width: 20, height: 10),
            exportPresets: deliveryPresets()
        )
        viewModel.document.slices = [slice]
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = slice.id
        viewModel.syncExportSettingsForCurrentSliceScope()
        #expect(viewModel.exportSettings.scale == 2)
        viewModel.pushUndo()
        viewModel.document.areGuidesVisible.toggle()
        viewModel.pushUndo()
        viewModel.document.areRulersVisible.toggle()
        viewModel.undo()
        let before = try documentData(viewModel.document)
        let undoCount = viewModel.undoStack.count
        let historyCount = viewModel.document.history.count
        #expect(!viewModel.redoStack.isEmpty)

        viewModel.crop(to: CGRect(x: 20, y: 20, width: 60, height: 40))

        let after = try documentData(viewModel.document)
        #expect(viewModel.document.slices.first?.frame == CGRect(x: 0, y: 10, width: 10, height: 10))
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(viewModel.redoStack.isEmpty)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.exportSettings.scale == 4)

        viewModel.undo()
        #expect(try documentData(viewModel.document) == before)
        #expect(viewModel.exportSettings.scale == 2)
        viewModel.redo()
        #expect(try documentData(viewModel.document) == after)
        #expect(viewModel.exportSettings.scale == 4)
    }

    @Test func cropToSelectionAndCropCenterShareSliceTransform() {
        let selectionCrop = makeViewModel()
        let selectionSlice = ImageEditorSlice(name: "Selection", frame: CGRect(x: 25, y: 15, width: 12, height: 10))
        selectionCrop.document.slices = [selectionSlice]
        selectionCrop.document.selection = .rectangle(CGRect(x: 20, y: 10, width: 50, height: 40))
        selectionCrop.cropToSelection()
        #expect(selectionCrop.document.canvasSize == CGSize(width: 50, height: 40))
        #expect(selectionCrop.document.slices.first?.frame == CGRect(x: 5, y: 5, width: 12, height: 10))

        let centerCrop = makeViewModel()
        centerCrop.document.slices = [ImageEditorSlice(name: "Center", frame: CGRect(x: 20, y: 20, width: 12, height: 10))]
        centerCrop.cropCenter()
        #expect(centerCrop.document.canvasSize == CGSize(width: 84, height: 68))
        #expect(centerCrop.document.slices.first?.frame == CGRect(x: 12, y: 14, width: 12, height: 10))
    }

    @Test func canvasTrimTransformsSlicesButLayerTrimDoesNot() throws {
        let canvasTrim = makeViewModel()
        let layerIndex = try #require(canvasTrim.document.selectedLayerIndex)
        canvasTrim.document.layers[layerIndex].frame = CGRect(x: 30, y: 22, width: 20, height: 16)
        canvasTrim.document.layers[layerIndex].image = NSImage.opaqueMask(size: CGSize(width: 20, height: 16))
        let clipped = ImageEditorSlice(name: "Clipped by canvas trim", frame: CGRect(x: 25, y: 20, width: 10, height: 10))
        let kept = ImageEditorSlice(name: "Canvas trim", frame: CGRect(x: 35, y: 27, width: 10, height: 8))
        canvasTrim.document.slices = [clipped, kept]
        canvasTrim.trimTransparentPixels()
        #expect(canvasTrim.document.canvasSize == CGSize(width: 20, height: 16))
        #expect(canvasTrim.document.slices.map(\.id) == [clipped.id, kept.id])
        #expect(canvasTrim.document.slices.map(\.frame) == [
            CGRect(x: 0, y: 0, width: 5, height: 8),
            CGRect(x: 5, y: 5, width: 10, height: 8)
        ])

        let layerTrim = makeViewModel()
        let selectedIndex = try #require(layerTrim.document.selectedLayerIndex)
        layerTrim.document.layers[selectedIndex].frame = CGRect(x: 20, y: 20, width: 40, height: 20)
        layerTrim.document.layers[selectedIndex].image = transparentEdgeImage()
        let slice = ImageEditorSlice(name: "Layer trim invariant", frame: CGRect(x: 25, y: 25, width: 12, height: 10))
        layerTrim.document.slices = [slice]
        layerTrim.trimSelectedLayerTransparentPixels()
        #expect(layerTrim.document.slices == [slice])
        #expect(layerTrim.document.canvasSize == CGSize(width: 100, height: 80))
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "slice-crop.png",
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

    private func transparentEdgeImage() -> NSImage {
        let image = NSImage(size: CGSize(width: 20, height: 10))
        image.lockFocus()
        NSColor.clear.setFill()
        CGRect(x: 0, y: 0, width: 20, height: 10).fill()
        NSColor.systemRed.setFill()
        CGRect(x: 5, y: 2, width: 10, height: 6).fill()
        image.unlockFocus()
        return image
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
