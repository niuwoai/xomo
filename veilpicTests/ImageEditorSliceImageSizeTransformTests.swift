import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSliceImageSizeTransformTests {
    @Test func pureScalingUsesVisibleSourceIntersectionAndPreservesDeliveryMetadata() throws {
        let id = UUID()
        let presets = [
            ImageEditorSliceExportPreset(
                suffix: "-width",
                format: .png,
                constraint: .width,
                value: 40
            ),
            ImageEditorSliceExportPreset(
                suffix: "-height",
                format: .jpeg,
                constraint: .height,
                value: 20
            ),
            ImageEditorSliceExportPreset(
                suffix: "-vector",
                format: .pdf,
                constraint: .scale,
                value: 1
            )
        ]
        let source = ImageEditorSlice(
            id: id,
            name: "  Raw Slice Name  ",
            frame: CGRect(x: 30.4, y: 27.6, width: -20.2, height: -15.2),
            exportPresets: presets
        )

        let transformed = try source.scaledForImageSize(
            scaleX: 1.5,
            scaleY: 0.5,
            sourceCanvasSize: CGSize(width: 100, height: 80),
            targetCanvasSize: CGSize(width: 150, height: 40)
        )

        #expect(transformed.frame == CGRect(x: 15, y: 6, width: 31, height: 8))
        #expect(transformed.id == id)
        #expect(transformed.name == "  Raw Slice Name  ")
        #expect(transformed.exportPresets == presets)

        let partiallyOutside = ImageEditorSlice(
            name: "Visible edge",
            frame: CGRect(x: -20, y: 220, width: 60, height: 40)
        )
        let clipped = try partiallyOutside.scaledForImageSize(
            scaleX: 0.5,
            scaleY: 2,
            sourceCanvasSize: CGSize(width: 320, height: 240),
            targetCanvasSize: CGSize(width: 160, height: 480)
        )
        #expect(clipped.frame == CGRect(x: 0, y: 440, width: 20, height: 40))
    }

    @Test func sourcePresetValidationUsesIntegralVisibleFrameNotRawGeometryWidth() {
        let preset = ImageEditorSliceExportPreset(
            suffix: "quarter-boundary",
            format: .png,
            constraint: .width,
            value: 16.2
        )
        let slice = ImageEditorSlice(
            name: "Fractional",
            frame: CGRect(x: 20.4, y: 40.4, width: 64.4, height: 38.6),
            exportPresets: [preset]
        )
        #expect(preset.resolvedScale(for: slice.frame.standardized) != nil)

        #expect(throws: (any Error).self) {
            _ = try slice.scaledForImageSize(
                scaleX: 0.5,
                scaleY: 2,
                sourceCanvasSize: CGSize(width: 320, height: 240),
                targetCanvasSize: CGSize(width: 160, height: 480)
            )
        }
    }

    @Test func partiallyOutsideSliceValidatesWidthPresetAgainstBothVisibleIntersections() throws {
        let preset = ImageEditorSliceExportPreset(
            suffix: "-visible-width",
            format: .png,
            constraint: .width,
            value: 7.75
        )
        let slice = ImageEditorSlice(
            name: "Crosses left edge",
            frame: CGRect(x: -10.2, y: 10, width: 30.4, height: 20),
            exportPresets: [preset]
        )

        let transformed = try slice.scaledForImageSize(
            scaleX: 1.5,
            scaleY: 0.5,
            sourceCanvasSize: CGSize(width: 100, height: 80),
            targetCanvasSize: CGSize(width: 150, height: 40)
        )

        // Source validation uses width 21 (integral visible intersection),
        // while target validation uses width 31 (final visible intersection).
        // The same preset would be below 0.25x against either unclipped frame.
        #expect(transformed.frame == CGRect(x: 0, y: 5, width: 31, height: 10))
        #expect(preset.resolvedScale(for: CGRect(x: 0, y: 10, width: 21, height: 20)) == 7.75 / 21)
        #expect(preset.resolvedScale(for: transformed.frame) == 0.25)
        #expect(transformed.exportPresets == [preset])
    }

    @Test func commandScalesPositiveAndNegativeFramesAndReprojectsAllPresetKinds() throws {
        let viewModel = makeViewModel()
        let firstID = UUID()
        let secondID = UUID()
        let presets = deliveryPresets()
        var emptyPresetSlice = ImageEditorSlice(
            id: secondID,
            name: "Equivalent Negative",
            frame: CGRect(x: 84.8, y: 79, width: -64.4, height: -38.6)
        )
        emptyPresetSlice.exportPresets = []
        viewModel.document.slices = [
            ImageEditorSlice(
                id: firstID,
                name: "Hero",
                frame: CGRect(x: 20.4, y: 40.4, width: 64.4, height: 38.6),
                exportPresets: presets
            ),
            emptyPresetSlice
        ]
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = firstID
        viewModel.exportSettings.batchScales = [2, 3]
        viewModel.exportSettings.filenameSuffix = "old"
        viewModel.canvasOffset = CGSize(width: 9, height: -4)

        viewModel.resizeImage(to: CGSize(width: 160, height: 480))

        #expect(viewModel.document.slices.map(\.id) == [firstID, secondID])
        #expect(viewModel.document.slices.map(\.frame) == [
            CGRect(x: 10, y: 80, width: 33, height: 78),
            CGRect(x: 10, y: 80, width: 33, height: 78)
        ])
        #expect(viewModel.document.slices[0].exportPresets == presets)
        #expect(viewModel.document.slices[1].exportPresets == [])
        #expect(viewModel.exportSettings.scope == .slice)
        #expect(viewModel.exportSettings.sliceID == firstID)
        #expect(viewModel.exportSettings.format == .png)
        #expect(viewModel.exportSettings.scale == 3)
        #expect(viewModel.exportSettings.batchScales.isEmpty)
        #expect(viewModel.exportSettings.filenameSuffix == "-width")
        #expect(viewModel.canvasOffset == .zero)
        #expect(viewModel.targetImageWidth == 160)
        #expect(viewModel.targetImageHeight == 480)

        let plan = viewModel.selectedSliceExportPlan(settings: viewModel.exportSettings)
        #expect(plan.map(\.settings.format) == [.png, .jpeg, .pdf])
        #expect(plan.map(\.settings.scale) == [3, 1.5, 1])
        #expect(plan.map(\.settings.filenameSuffix) == ["-width", "-height", "-vector"])
    }

    @Test func successfulResizeIsOneTransactionAndUndoRedoReprojectsSelectedPreset() throws {
        let viewModel = makeViewModel()
        let slice = ImageEditorSlice(
            name: "Hero",
            frame: CGRect(x: 20.4, y: 40.4, width: 64.4, height: 38.6),
            exportPresets: deliveryPresets()
        )
        viewModel.document.slices = [slice]
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = slice.id
        viewModel.pushUndo()
        viewModel.document.areGuidesVisible.toggle()
        viewModel.pushUndo()
        viewModel.document.areRulersVisible.toggle()
        viewModel.undo()
        let beforeResize = try documentData(viewModel.document)
        let undoCount = viewModel.undoStack.count
        let historyCount = viewModel.document.history.count
        #expect(!viewModel.redoStack.isEmpty)

        viewModel.resizeImage(to: CGSize(width: 160, height: 480))

        let afterResize = try documentData(viewModel.document)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(viewModel.redoStack.isEmpty)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.imageResize"))
        #expect(viewModel.exportSettings.scale == 3)

        viewModel.undo()
        #expect(try documentData(viewModel.document) == beforeResize)
        #expect(viewModel.exportSettings.sliceID == slice.id)
        let sourceScale = 99 / Double(64.4)
        #expect(abs(viewModel.exportSettings.scale - sourceScale) < 0.000_001)

        viewModel.redo()
        #expect(try documentData(viewModel.document) == afterResize)
        #expect(viewModel.exportSettings.sliceID == slice.id)
        #expect(viewModel.exportSettings.scale == 3)
    }

    @Test func sliceScopeRepairsNilStaleAndEmptySelectionsWhileOtherScopesRemainUntouched() {
        for selection in [UUID?.none, UUID?.some(UUID())] {
            let viewModel = makeViewModel()
            let slice = ImageEditorSlice(
                name: "First",
                frame: CGRect(x: 20, y: 40, width: 60, height: 40),
                exportPresets: [
                    ImageEditorSliceExportPreset(
                        suffix: "@2x",
                        format: .jpeg,
                        constraint: .scale,
                        value: 2
                    )
                ]
            )
            viewModel.document.slices = [slice]
            viewModel.exportSettings.scope = .slice
            viewModel.exportSettings.sliceID = selection

            viewModel.resizeImage(to: CGSize(width: 160, height: 480))

            #expect(viewModel.exportSettings.sliceID == slice.id)
            #expect(viewModel.exportSettings.format == .jpeg)
            #expect(viewModel.exportSettings.scale == 2)
            #expect(viewModel.exportSettings.filenameSuffix == "@2x")
        }

        let empty = makeViewModel()
        empty.exportSettings.scope = .slice
        empty.exportSettings.sliceID = UUID()
        empty.exportSettings.filenameSuffix = "stale"
        empty.resizeImage(to: CGSize(width: 160, height: 480))
        #expect(empty.exportSettings.scope == .composited)
        #expect(empty.exportSettings.sliceID == nil)
        #expect(empty.exportSettings.filenameSuffix.isEmpty)

        let noPreset = makeViewModel()
        let noPresetSlice = ImageEditorSlice(
            name: "No preset",
            frame: CGRect(x: 20, y: 40, width: 60, height: 40)
        )
        noPreset.document.slices = [noPresetSlice]
        noPreset.exportSettings.scope = .slice
        noPreset.exportSettings.sliceID = noPresetSlice.id
        noPreset.exportSettings.format = .jpeg
        noPreset.exportSettings.scale = 2
        noPreset.exportSettings.batchScales = [1, 3]
        noPreset.exportSettings.filenameSuffix = "stale"
        noPreset.resizeImage(to: CGSize(width: 160, height: 480))
        #expect(noPreset.exportSettings.format == .jpeg)
        #expect(noPreset.exportSettings.scale == 2)
        #expect(noPreset.exportSettings.batchScales == [1, 3])
        #expect(noPreset.exportSettings.filenameSuffix.isEmpty)

        let nonSlice = makeViewModel()
        nonSlice.document.slices = [ImageEditorSlice(
            name: "Metadata",
            frame: CGRect(x: 20, y: 40, width: 60, height: 40)
        )]
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
        let settingsBefore = nonSlice.exportSettings
        nonSlice.resizeImage(to: CGSize(width: 160, height: 480))
        #expect(nonSlice.exportSettings == settingsBefore)
    }

    @Test func invalidSliceOrPresetRejectsResizeBeforeUndoAtomically() throws {
        let invalidSlices: [ImageEditorSlice] = [
            ImageEditorSlice(name: "Zero", frame: CGRect(x: 10, y: 10, width: 0, height: 20)),
            ImageEditorSlice(name: "NaN", frame: CGRect(x: CGFloat.nan, y: 10, width: 20, height: 20)),
            ImageEditorSlice(name: "Infinity", frame: CGRect(x: 10, y: 10, width: CGFloat.infinity, height: 20)),
            ImageEditorSlice(name: "Overflow", frame: CGRect(x: CGFloat.greatestFiniteMagnitude, y: 0, width: CGFloat.greatestFiniteMagnitude, height: 20)),
            ImageEditorSlice(name: "Outside", frame: CGRect(x: 400, y: 300, width: 20, height: 20)),
            sliceWithPresets(Array(repeating: ImageEditorSliceExportPreset(
                suffix: "x",
                format: .png,
                constraint: .scale,
                value: 1
            ), count: ImageEditorSlice.maximumExportPresetCount + 1)),
            sliceWithPresets([ImageEditorSliceExportPreset(
                suffix: "unsupported",
                format: .webp,
                constraint: .scale,
                value: 1
            )]),
            sliceWithPresets([ImageEditorSliceExportPreset(
                suffix: "bad-value",
                format: .png,
                constraint: .scale,
                value: .nan
            )]),
            sliceWithPresets([ImageEditorSliceExportPreset(
                suffix: "source-scale",
                format: .png,
                constraint: .width,
                value: 10
            )]),
            sliceWithPresets([ImageEditorSliceExportPreset(
                suffix: "target-scale",
                format: .png,
                constraint: .width,
                value: 150
            )])
        ]

        for invalidSlice in invalidSlices {
            let viewModel = makeViewModel()
            viewModel.document.slices = [invalidSlice]
            viewModel.exportSettings.scope = .slice
            viewModel.exportSettings.sliceID = invalidSlice.id
            viewModel.isSlicesPanelVisible = true
            viewModel.isHotspotsPanelVisible = true
            viewModel.canvasOffset = CGSize(width: 7, height: -3)
            viewModel.targetImageWidth = 123
            viewModel.targetImageHeight = 124
            viewModel.targetCanvasWidth = 125
            viewModel.targetCanvasHeight = 126
            viewModel.pushUndo()
            viewModel.document.areGuidesVisible.toggle()
            viewModel.pushUndo()
            viewModel.document.areRulersVisible.toggle()
            viewModel.undo()
            let snapshot = try atomicSnapshot(viewModel)

            viewModel.resizeImage(to: CGSize(width: 160, height: 480))

            #expect(try atomicSnapshot(viewModel) == snapshot)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
        }
    }

    @Test func invalidSourceCanvasRejectsBeforeUndo() throws {
        let invalidSourceSizes = [
            CGSize(width: 0, height: 240),
            CGSize(width: -1, height: 240),
            CGSize(width: CGFloat.nan, height: 240),
            CGSize(width: CGFloat.infinity, height: 240),
            CGSize(width: 320, height: 0),
            CGSize(width: 320, height: -1),
            CGSize(width: 320, height: CGFloat.nan),
            CGSize(width: 320, height: CGFloat.infinity)
        ]

        for sourceSize in invalidSourceSizes {
            let viewModel = makeViewModel()
            viewModel.document.slices = [ImageEditorSlice(
                name: "Hero",
                frame: CGRect(x: 20, y: 40, width: 60, height: 40)
            )]
            viewModel.document.canvasSize = sourceSize
            let snapshot = try atomicSnapshot(viewModel)

            viewModel.resizeImage(to: CGSize(width: 160, height: 480))

            #expect(try atomicSnapshot(viewModel) == snapshot)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.resizeInvalid"))
        }
    }

    @Test func imageSizeResamplingKeepsPixelArtCrispAndPhotoEdgesSmoothWithOneUndo() throws {
        let source = try #require(NSImage.rendered(size: CGSize(width: 8, height: 8)) { _ in
            NSColor.red.setFill()
            NSBezierPath(rect: CGRect(x: 0, y: 0, width: 4, height: 8)).fill()
            NSColor.blue.setFill()
            NSBezierPath(rect: CGRect(x: 4, y: 0, width: 4, height: 8)).fill()
        })

        let channelMask = ImageEditorSelectionMask(
            width: 8,
            height: 8,
            alpha: (0..<64).map { $0 % 8 < 4 ? UInt8(0) : UInt8(255) }
        )
        for mode in ImageEditorImageResampling.allCases {
            let viewModel = ImageEditorViewModel(sourceName: "image-size-resampling.png", image: source) { _ in }
            viewModel.selectedImageResampling = mode
            viewModel.targetImageWidth = 16
            viewModel.targetImageHeight = 16
            viewModel.document.alphaChannels = [ImageEditorAlphaChannel(name: "Edge", mask: channelMask)]
            let original = try viewModel.projectData()
            let undoCount = viewModel.undoStack.count

            viewModel.resizeImageToControlSize()

            let resized = try #require(viewModel.document.layers.first?.image)
            let samples = try (0..<16).map { x -> NSColor in
                try #require(resized.color(at: CGPoint(x: CGFloat(x) + 0.5, y: 0.5)))
            }
            let resizedChannel = try #require(viewModel.document.alphaChannels.first?.mask)
            let channelSamples = (0..<16).map { resizedChannel.alpha[$0] }
            #expect(viewModel.undoStack.count == undoCount + 1)
            if mode == .nearestNeighbor {
                #expect(samples.allSatisfy {
                    ($0.redComponent > 0.99 && $0.blueComponent < 0.01)
                        || ($0.blueComponent > 0.99 && $0.redComponent < 0.01)
                })
                #expect(channelSamples.allSatisfy { $0 == 0 || $0 == 255 })
            } else {
                #expect(samples.contains { $0.redComponent > 0.05 && $0.blueComponent > 0.05 })
                #expect(channelSamples.contains { $0 > 0 && $0 < 255 })
            }

            let resizedProject = try viewModel.projectData()
            viewModel.undo()
            #expect(try viewModel.projectData() == original)
            viewModel.redo()
            #expect(try viewModel.projectData() == resizedProject)
        }
    }

    @Test func imageSizeControlsConstrainProportionsUntilUnlocked() throws {
        let viewModel = makeViewModel()
        viewModel.document.canvasSize = CGSize(width: 160, height: 80)
        viewModel.syncSizeControlsFromDocument()

        #expect(viewModel.isImageSizeAspectRatioLocked)
        viewModel.setTargetImageWidth(240)
        #expect(viewModel.targetImageWidth == 240)
        #expect(viewModel.targetImageHeight == 120)

        viewModel.setTargetImageHeight(60)
        #expect(viewModel.targetImageWidth == 120)
        #expect(viewModel.targetImageHeight == 60)

        viewModel.setImageSizeAspectRatioLocked(false)
        viewModel.setTargetImageWidth(200)
        #expect(viewModel.targetImageWidth == 200)
        #expect(viewModel.targetImageHeight == 60)

        viewModel.setImageSizeAspectRatioLocked(true)
        #expect(viewModel.targetImageWidth == 200)
        #expect(viewModel.targetImageHeight == 100)

        let originalProject = try viewModel.projectData()
        let undoCount = viewModel.undoStack.count
        viewModel.resizeImageToControlSize()
        #expect(viewModel.document.canvasSize == CGSize(width: 200, height: 100))
        #expect(viewModel.undoStack.count == undoCount + 1)
        let resizedProject = try viewModel.projectData()
        viewModel.undo()
        #expect(try viewModel.projectData() == originalProject)
        viewModel.redo()
        #expect(try viewModel.projectData() == resizedProject)
    }

    @Test func imageSizeResamplingPreservesFeatheredActiveAndSavedSelections() throws {
        let source = NSImage.transparent(size: CGSize(width: 8, height: 8))
        let featheredMask = ImageEditorSelectionMask(
            width: 8,
            height: 8,
            alpha: (0..<64).map { x in
                [UInt8(0), 0, 0, 0, 64, 192, 255, 255][x % 8]
            }
        )

        for mode in ImageEditorImageResampling.allCases {
            let viewModel = ImageEditorViewModel(sourceName: "selection-resampling.png", image: source) { _ in }
            let selection = ImageEditorSelection.raster(
                mask: featheredMask,
                bounds: CGRect(x: 0, y: 0, width: 8, height: 8)
            )
            viewModel.document.selection = selection
            viewModel.document.savedSelection = selection
            let originalProject = try viewModel.projectData()

            viewModel.resizeImage(to: CGSize(width: 16, height: 16), resampling: mode)

            let activeMask = try #require(viewModel.document.selection?.rasterMask)
            let savedMask = try #require(viewModel.document.savedSelection?.rasterMask)
            #expect(activeMask.width == 16)
            #expect(savedMask.width == 16)
            if mode == .nearestNeighbor {
                #expect(activeMask.alpha[7] == 0 && activeMask.alpha[8] == 64)
                #expect(savedMask.alpha[7] == 0 && savedMask.alpha[8] == 64)
            } else {
                #expect(activeMask.alpha[7] > 0 && activeMask.alpha[7] < 64)
                #expect(activeMask.alpha[8] > 0 && activeMask.alpha[8] < 64)
                #expect(savedMask.alpha == activeMask.alpha)
            }

            let resizedProject = try viewModel.projectData()
            viewModel.undo()
            #expect(try viewModel.projectData() == originalProject)
            viewModel.redo()
            #expect(try viewModel.projectData() == resizedProject)
        }
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "slice-image-size.png",
            image: NSImage.transparent(size: CGSize(width: 320, height: 240))
        ) { _ in }
    }

    private func deliveryPresets() -> [ImageEditorSliceExportPreset] {
        [
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
    }

    private func sliceWithPresets(
        _ presets: [ImageEditorSliceExportPreset]
    ) -> ImageEditorSlice {
        ImageEditorSlice(
            name: "Preset validation",
            frame: CGRect(x: 20.4, y: 40.4, width: 64.4, height: 38.6),
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
            isSlicesPanelVisible: viewModel.isSlicesPanelVisible,
            isHotspotsPanelVisible: viewModel.isHotspotsPanelVisible,
            canvasOffset: viewModel.canvasOffset,
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
        let isSlicesPanelVisible: Bool
        let isHotspotsPanelVisible: Bool
        let canvasOffset: CGSize
        let targetImageWidth: Double
        let targetImageHeight: Double
        let targetCanvasWidth: Double
        let targetCanvasHeight: Double
    }
}
