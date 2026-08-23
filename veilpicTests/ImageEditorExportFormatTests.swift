import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorExportFormatTests {
    @Test func exportScaleFormatterPreservesQuarterStepsWithoutTrailingZeros() {
        #expect(ImageEditorExportScaleFormatter.string(from: 1) == "1")
        #expect(ImageEditorExportScaleFormatter.string(from: 1.25) == "1.25")
        #expect(ImageEditorExportScaleFormatter.string(from: 1.5) == "1.5")
        #expect(ImageEditorExportScaleFormatter.string(from: 2.75) == "2.75")
        #expect(ImageEditorSliceExportPreset.defaultSuffix(forScale: 1) == "")
        #expect(ImageEditorSliceExportPreset.defaultSuffix(forScale: 1.5) == "@1.5x")
        #expect(ImageEditorSliceExportPreset.defaultSuffix(forScale: 2.75) == "@2.75x")
    }

    @Test func previewAndExportPanelsAreNonClosingAndMutuallyExclusive() {
        let viewModel = ImageEditorViewModel(
            sourceName: "panel-routing",
            image: NSImage.transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }

        viewModel.openPreviewPanel()
        #expect(viewModel.isPreviewSheetPresented)
        #expect(!viewModel.isExportSheetPresented)

        viewModel.openExportPanel()
        #expect(!viewModel.isPreviewSheetPresented)
        #expect(viewModel.isExportSheetPresented)
    }

    @Test func previewBackdropInspectsTransparencyWithoutEditingTheDocument() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "preview-backdrop",
            image: NSImage.transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let originalLayerCount = viewModel.document.layers.count
        let originalHistory = viewModel.document.history
        let originalCanUndo = viewModel.canUndo

        #expect(ImageEditorPreviewBackdrop.allCases.map(\.rawValue) == [
            "checkerboard", "white", "black"
        ])
        #expect(ImageEditorPreviewBackdrop.checkerboard.solidColor == nil)
        let white = try #require(
            ImageEditorPreviewBackdrop.white.solidColor?.usingColorSpace(.deviceRGB)
        )
        let black = try #require(
            ImageEditorPreviewBackdrop.black.solidColor?.usingColorSpace(.deviceRGB)
        )
        #expect(white.redComponent == 1)
        #expect(white.greenComponent == 1)
        #expect(white.blueComponent == 1)
        #expect(black.redComponent == 0)
        #expect(black.greenComponent == 0)
        #expect(black.blueComponent == 0)

        viewModel.previewBackdrop = .black
        viewModel.openPreviewPanel()
        viewModel.isPreviewSheetPresented = false
        viewModel.openPreviewPanel()

        #expect(viewModel.previewBackdrop == .black)
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.layers.count == originalLayerCount)
        #expect(viewModel.document.history == originalHistory)
        #expect(viewModel.canUndo == originalCanUndo)
    }

    @Test func previewZoomFitsViewportOrMagnifiesPixelDimensions() {
        let canvasSize = CGSize(width: 800, height: 400)
        let viewportSize = CGSize(width: 320, height: 240)

        #expect(ImageEditorPreviewZoomMode.allCases.map(\.rawValue) == [
            "fit", "actualPixels", "doublePixels"
        ])
        #expect(
            ImageEditorPreviewZoomMode.fit.displayedImageSize(
                canvasSize: canvasSize,
                viewportSize: viewportSize
            ) == CGSize(width: 320, height: 160)
        )
        #expect(
            ImageEditorPreviewZoomMode.actualPixels.displayedImageSize(
                canvasSize: canvasSize,
                viewportSize: viewportSize
            ) == canvasSize
        )
        #expect(
            ImageEditorPreviewZoomMode.doublePixels.displayedImageSize(
                canvasSize: canvasSize,
                viewportSize: viewportSize
            ) == CGSize(width: 1_600, height: 800)
        )
        #expect(!ImageEditorPreviewZoomMode.fit.usesScrollablePixelCanvas)
        #expect(ImageEditorPreviewZoomMode.actualPixels.usesScrollablePixelCanvas)
        #expect(ImageEditorPreviewZoomMode.doublePixels.usesScrollablePixelCanvas)
        #expect(
            ImageEditorPreviewZoomMode.fit.displayedImageSize(
                canvasSize: canvasSize,
                viewportSize: .zero
            ) == .zero
        )

        let viewModel = ImageEditorViewModel(
            sourceName: "preview-zoom",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let originalHistory = viewModel.document.history
        let originalCanUndo = viewModel.canUndo

        #expect(viewModel.previewZoomMode == .fit)
        viewModel.previewZoomMode = .doublePixels
        viewModel.openPreviewPanel()
        viewModel.isPreviewSheetPresented = false
        viewModel.openPreviewPanel()

        #expect(viewModel.previewZoomMode == .doublePixels)
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.history == originalHistory)
        #expect(viewModel.canUndo == originalCanUndo)
    }

    @Test func previewPixelInspectionMapsEveryZoomToCanvasCoordinates() throws {
        let canvasSize = CGSize(width: 80, height: 40)

        #expect(
            ImageEditorPreviewPixelSample.canvasPoint(
                from: CGPoint(x: 82, y: 42),
                displayedSize: CGSize(width: 320, height: 160),
                canvasSize: canvasSize
            ) == CGPoint(x: 20, y: 10)
        )
        #expect(
            ImageEditorPreviewPixelSample.canvasPoint(
                from: CGPoint(x: 41, y: 21),
                displayedSize: CGSize(width: 160, height: 80),
                canvasSize: canvasSize
            ) == CGPoint(x: 20, y: 10)
        )
        #expect(
            ImageEditorPreviewPixelSample.canvasPoint(
                from: CGPoint(x: -1, y: 4),
                displayedSize: canvasSize,
                canvasSize: canvasSize
            ) == nil
        )
        #expect(
            ImageEditorPreviewPixelSample.canvasPoint(
                from: CGPoint(x: canvasSize.width, y: 4),
                displayedSize: canvasSize,
                canvasSize: canvasSize
            ) == nil
        )

        let image = try #require(NSImage.rendered(size: canvasSize) { rect in
            NSColor(deviceRed: 1, green: 0.5, blue: 0, alpha: 0.25).setFill()
            rect.fill()
        })
        let sample = try #require(
            ImageEditorPreviewPixelSample.sample(
                image: image,
                location: CGPoint(x: 20.5, y: 10.5),
                displayedSize: canvasSize,
                canvasSize: canvasSize
            )
        )
        #expect(sample.point == CGPoint(x: 20, y: 10))
        #expect(sample.text.contains("X 20"))
        #expect(sample.text.contains("Y 10"))
        #expect(sample.text.contains("#FF800040"))
    }

    @Test func previewPixelInspectionFormatsClassicColorReadoutModes() {
        let sample = ImageEditorPreviewPixelSample(
            point: CGPoint(x: 20, y: 10),
            color: NSColor(deviceRed: 1, green: 0.5, blue: 0, alpha: 0.25)
        )

        #expect(ImageEditorPreviewPixelReadoutMode.allCases.map(\.rawValue) == [
            "hexadecimalRGBA", "rgb", "hsb", "cmyk"
        ])
        #expect(sample.text(mode: .hexadecimalRGBA).contains("#FF800040"))
        #expect(sample.text(mode: .rgb).contains("R 255  G 128  B 0  A 25%"))
        #expect(sample.text(mode: .hsb).contains("H 30°  S 100%  B 100%  A 25%"))
        #expect(sample.text(mode: .cmyk).contains("C 0%  M 50%  Y 100%  K 0%  A 25%"))
        for mode in ImageEditorPreviewPixelReadoutMode.allCases {
            #expect(sample.text(mode: mode).contains("X 20"))
            #expect(sample.text(mode: mode).contains("Y 10"))
        }
    }

    @Test func previewPixelReadoutCopiesToAnIsolatedPasteboard() {
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("xomo-tests.preview-pixel-copy.\(UUID().uuidString)")
        )
        defer { pasteboard.clearContents() }
        pasteboard.clearContents()
        pasteboard.setString("existing", forType: .string)

        #expect(!ImageEditorPreviewClipboard.copy("", to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "existing")

        let sample = ImageEditorPreviewPixelSample(
            point: CGPoint(x: 20, y: 10),
            color: NSColor(deviceRed: 1, green: 0.5, blue: 0, alpha: 0.25)
        )
        let hexadecimal = sample.valueText(mode: .hexadecimalRGBA)
        #expect(ImageEditorPreviewClipboard.copy(hexadecimal, to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "#FF800040")

        let rgb = sample.valueText(mode: .rgb)
        #expect(ImageEditorPreviewClipboard.copy(rgb, to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "R 255  G 128  B 0  A 25%")
    }

    @Test func previewPixelInspectionPinsFallbackAndMapsItsCanvasMarker() {
        let pinned = ImageEditorPreviewPixelSample(
            point: CGPoint(x: 20, y: 10),
            color: .systemOrange
        )
        let live = ImageEditorPreviewPixelSample(
            point: CGPoint(x: 3, y: 4),
            color: .systemBlue
        )

        #expect(
            ImageEditorPreviewPixelSample.resolved(live: live, pinned: pinned)?.point == live.point
        )
        #expect(
            ImageEditorPreviewPixelSample.resolved(live: nil, pinned: pinned)?.point == pinned.point
        )
        #expect(ImageEditorPreviewPixelSample.resolved(live: nil, pinned: nil) == nil)
        #expect(
            pinned.displayedCenter(
                displayedSize: CGSize(width: 320, height: 160),
                canvasSize: CGSize(width: 80, height: 40)
            ) == CGPoint(x: 82, y: 42)
        )
        #expect(
            pinned.displayedCenter(
                displayedSize: CGSize(width: 160, height: 80),
                canvasSize: CGSize(width: 80, height: 40)
            ) == CGPoint(x: 41, y: 21)
        )
        #expect(
            pinned.displayedCenter(
                displayedSize: .zero,
                canvasSize: CGSize(width: 80, height: 40)
            ) == nil
        )
    }

    @Test func previewPixelInspectionKeepsFourStableNumberedSamples() {
        var pinnedSamples = ImageEditorPreviewPinnedSamples()
        let samples = (0..<5).map { offset in
            ImageEditorPreviewPixelSample(
                point: CGPoint(x: offset, y: offset + 10),
                color: NSColor(
                    deviceRed: CGFloat(offset) / 5,
                    green: 0.5,
                    blue: 1,
                    alpha: 1
                )
            )
        }

        for index in 0..<ImageEditorPreviewPinnedSamples.maximumCount {
            let pinnedSample = pinnedSamples.pin(samples[index])
            #expect(pinnedSample?.number == index + 1)
        }
        #expect(pinnedSamples.entries.map(\.number) == [1, 2, 3, 4])
        #expect(pinnedSamples.latest?.sample.point == samples[3].point)

        let overflowSample = pinnedSamples.pin(samples[4])
        #expect(overflowSample == nil)
        #expect(pinnedSamples.entries.count == ImageEditorPreviewPinnedSamples.maximumCount)
        #expect(pinnedSamples.latest?.sample.point == samples[3].point)

        let removedSample = pinnedSamples.remove(number: 2)
        let removedMissingSample = pinnedSamples.remove(number: 2)
        let reusedSample = pinnedSamples.pin(samples[4])
        #expect(removedSample)
        #expect(!removedMissingSample)
        #expect(reusedSample?.number == 2)
        #expect(pinnedSamples.entries.map(\.number) == [1, 3, 4, 2])
        #expect(pinnedSamples.latest?.sample.point == samples[4].point)

        pinnedSamples.removeAll()
        #expect(pinnedSamples.entries.isEmpty)
        #expect(pinnedSamples.latest == nil)
    }

    @Test func previewPinnedSamplesMoveStableMarkerWithoutChangingItsIdentity() throws {
        var pinnedSamples = ImageEditorPreviewPinnedSamples()
        let first = ImageEditorPreviewPixelSample(
            point: CGPoint(x: 2, y: 3),
            color: .red
        )
        let second = ImageEditorPreviewPixelSample(
            point: CGPoint(x: 6, y: 7),
            color: .green
        )
        let third = ImageEditorPreviewPixelSample(
            point: CGPoint(x: 10, y: 12),
            color: .blue
        )
        _ = pinnedSamples.pin(first, readoutMode: .rgb)
        _ = pinnedSamples.pin(second, readoutMode: .cmyk)
        _ = pinnedSamples.pin(third, readoutMode: .hsb)

        let missingMove = pinnedSamples.move(
            number: 4,
            to: ImageEditorPreviewPixelSample(point: CGPoint(x: 8, y: 9), color: .yellow)
        )
        let samePixelMove = pinnedSamples.move(
            number: 2,
            to: ImageEditorPreviewPixelSample(point: second.point, color: .yellow)
        )
        let moved = pinnedSamples.move(
            number: 2,
            to: ImageEditorPreviewPixelSample(point: CGPoint(x: 14, y: 15), color: .yellow)
        )

        #expect(!missingMove)
        #expect(!samePixelMove)
        #expect(moved)
        #expect(pinnedSamples.entries.map(\.number) == [1, 2, 3])
        #expect(pinnedSamples.entries.map(\.readoutMode) == [.rgb, .cmyk, .hsb])
        let movedSample = try #require(
            pinnedSamples.entries.first(where: { $0.number == 2 })
        )
        #expect(movedSample.sample.point == CGPoint(x: 14, y: 15))
        #expect(movedSample.sample.color.isEqual(NSColor.yellow))
        #expect(pinnedSamples.latest?.number == 3)
        #expect(pinnedSamples.latest?.sample.point == third.point)

        var selection = ImageEditorPreviewSampleMeasurementSelection()
        selection.setFrom(1, in: pinnedSamples)
        selection.setTo(2, in: pinnedSamples)
        let measurement = try #require(selection.measurement(in: pinnedSamples))
        #expect(measurement.deltaX == 12)
        #expect(measurement.deltaY == 12)

        var dragTarget = ImageEditorPreviewMarkerDragTarget()
        let displayedSize = CGSize(width: 200, height: 200)
        let canvasSize = CGSize(width: 20, height: 20)
        let firstResolvedNumber = dragTarget.resolve(
            startingAt: CGPoint(x: 145, y: 155),
            samples: pinnedSamples,
            displayedSize: displayedSize,
            canvasSize: canvasSize
        )
        #expect(firstResolvedNumber == 2)
        _ = pinnedSamples.move(
            number: 2,
            to: ImageEditorPreviewPixelSample(point: CGPoint(x: 1, y: 1), color: .orange)
        )
        let retainedNumber = dragTarget.resolve(
            startingAt: CGPoint(x: 145, y: 155),
            samples: pinnedSamples,
            displayedSize: displayedSize,
            canvasSize: canvasSize
        )
        #expect(retainedNumber == 2)

        dragTarget.reset()
        let blankStart = dragTarget.resolve(
            startingAt: CGPoint(x: 195, y: 195),
            samples: pinnedSamples,
            displayedSize: displayedSize,
            canvasSize: canvasSize
        )
        _ = pinnedSamples.move(
            number: 2,
            to: ImageEditorPreviewPixelSample(point: CGPoint(x: 19, y: 19), color: .purple)
        )
        let blankRemainsUnresolved = dragTarget.resolve(
            startingAt: CGPoint(x: 195, y: 195),
            samples: pinnedSamples,
            displayedSize: displayedSize,
            canvasSize: canvasSize
        )
        #expect(blankStart == nil)
        #expect(blankRemainsUnresolved == nil)

        let nextGestureResolvesItsOwnStart = dragTarget.resolve(
            startingAt: CGPoint(x: 25, y: 35),
            samples: pinnedSamples,
            displayedSize: displayedSize,
            canvasSize: canvasSize
        )
        #expect(nextGestureResolvesItsOwnStart == 1)
    }

    @Test func previewMarkerShiftDragConstrainsOnlyTheSelectedMeasurementEndpoint() throws {
        var pinnedSamples = ImageEditorPreviewPinnedSamples()
        _ = pinnedSamples.pin(
            ImageEditorPreviewPixelSample(point: CGPoint(x: 2, y: 3), color: .red)
        )
        _ = pinnedSamples.pin(
            ImageEditorPreviewPixelSample(point: CGPoint(x: 14, y: 15), color: .green)
        )
        _ = pinnedSamples.pin(
            ImageEditorPreviewPixelSample(point: CGPoint(x: 10, y: 12), color: .blue)
        )
        var selection = ImageEditorPreviewSampleMeasurementSelection()
        selection.setFrom(1, in: pinnedSamples)
        selection.setTo(2, in: pinnedSamples)
        let displayedSize = CGSize(width: 200, height: 200)
        let canvasSize = CGSize(width: 20, height: 20)

        let freeProposal = CGPoint(x: 170, y: 65)
        let unconstrained = ImageEditorPreviewMarkerDragConstraint.location(
            proposedLocation: freeProposal,
            markerNumber: 2,
            selection: selection,
            samples: pinnedSamples,
            displayedSize: displayedSize,
            canvasSize: canvasSize,
            modifierFlags: []
        )
        let horizontal = ImageEditorPreviewMarkerDragConstraint.location(
            proposedLocation: freeProposal,
            markerNumber: 2,
            selection: selection,
            samples: pinnedSamples,
            displayedSize: displayedSize,
            canvasSize: canvasSize,
            modifierFlags: [.shift]
        )
        let vertical = ImageEditorPreviewMarkerDragConstraint.location(
            proposedLocation: CGPoint(x: 55, y: 190),
            markerNumber: 2,
            selection: selection,
            samples: pinnedSamples,
            displayedSize: displayedSize,
            canvasSize: canvasSize,
            modifierFlags: [.shift, .command]
        )
        let horizontalTie = ImageEditorPreviewMarkerDragConstraint.location(
            proposedLocation: CGPoint(x: 75, y: 85),
            markerNumber: 2,
            selection: selection,
            samples: pinnedSamples,
            displayedSize: displayedSize,
            canvasSize: canvasSize,
            modifierFlags: [.shift]
        )
        let constrainedOrigin = ImageEditorPreviewMarkerDragConstraint.location(
            proposedLocation: CGPoint(x: 190, y: 180),
            markerNumber: 1,
            selection: selection,
            samples: pinnedSamples,
            displayedSize: displayedSize,
            canvasSize: canvasSize,
            modifierFlags: [.shift]
        )

        #expect(unconstrained == freeProposal)
        #expect(horizontal == CGPoint(x: 170, y: 35))
        #expect(vertical == CGPoint(x: 25, y: 190))
        #expect(horizontalTie == CGPoint(x: 75, y: 35))
        #expect(constrainedOrigin == CGPoint(x: 190, y: 155))
        let horizontalCanvasPoint = try #require(
            ImageEditorPreviewPixelSample.canvasPoint(
                from: horizontal,
                displayedSize: displayedSize,
                canvasSize: canvasSize
            )
        )
        let verticalCanvasPoint = try #require(
            ImageEditorPreviewPixelSample.canvasPoint(
                from: vertical,
                displayedSize: displayedSize,
                canvasSize: canvasSize
            )
        )
        #expect(horizontalCanvasPoint.y == 3)
        #expect(verticalCanvasPoint.x == 2)

        let nonEndpoint = ImageEditorPreviewMarkerDragConstraint.location(
            proposedLocation: freeProposal,
            markerNumber: 3,
            selection: selection,
            samples: pinnedSamples,
            displayedSize: displayedSize,
            canvasSize: canvasSize,
            modifierFlags: [.shift]
        )
        let invalidGeometry = ImageEditorPreviewMarkerDragConstraint.location(
            proposedLocation: freeProposal,
            markerNumber: 2,
            selection: selection,
            samples: pinnedSamples,
            displayedSize: .zero,
            canvasSize: canvasSize,
            modifierFlags: [.shift]
        )
        #expect(nonEndpoint == freeProposal)
        #expect(invalidGeometry == freeProposal)
    }

    @Test func previewMarkerCursorExpressesMoveAndOptionRemovalActions() {
        let move = ImageEditorCanvasCursor.objectMoveCursor()
        let removal = ImageEditorCanvasCursor.colorSamplerRemovalCursor()

        #expect(ImageEditorPreviewMarkerCursor.cursor(
            hoveredMarkerNumber: nil,
            draggedMarkerNumber: nil,
            modifierFlags: [.option]
        ) === NSCursor.arrow)
        #expect(ImageEditorPreviewMarkerCursor.cursor(
            hoveredMarkerNumber: 2,
            draggedMarkerNumber: nil,
            modifierFlags: []
        ) === move)
        #expect(ImageEditorPreviewMarkerCursor.cursor(
            hoveredMarkerNumber: 2,
            draggedMarkerNumber: nil,
            modifierFlags: [.shift]
        ) === move)
        #expect(ImageEditorPreviewMarkerCursor.cursor(
            hoveredMarkerNumber: 2,
            draggedMarkerNumber: nil,
            modifierFlags: [.option]
        ) === removal)
        #expect(ImageEditorPreviewMarkerCursor.cursor(
            hoveredMarkerNumber: 2,
            draggedMarkerNumber: 2,
            modifierFlags: [.option]
        ) === move)
        #expect(ImageEditorPreviewMarkerCursor.cursor(
            hoveredMarkerNumber: nil,
            draggedMarkerNumber: 2,
            modifierFlags: []
        ) === move)
        #expect(removal !== NSCursor.arrow)
        #expect(removal !== move)
    }

    @Test func previewMarkerModifierTrackingKeepsOnlyCursorActionFlags() {
        #expect(ImageEditorPreviewMarkerModifierFlags.tracked(from: []) == [])
        #expect(ImageEditorPreviewMarkerModifierFlags.tracked(
            from: [.command, .control, .capsLock]
        ) == [])
        #expect(ImageEditorPreviewMarkerModifierFlags.tracked(
            from: [.option, .command, .capsLock]
        ) == [.option])
        #expect(ImageEditorPreviewMarkerModifierFlags.tracked(
            from: [.shift, .option, .control]
        ) == [.shift, .option])
    }

    @Test func previewPinnedSampleMarkersResolveTheTopmostHitWithoutPinningAgain() {
        var pinnedSamples = ImageEditorPreviewPinnedSamples()
        let first = pinnedSamples.pin(
            ImageEditorPreviewPixelSample(point: CGPoint(x: 2, y: 3), color: .red)
        )
        let overlapping = pinnedSamples.pin(
            ImageEditorPreviewPixelSample(point: CGPoint(x: 2, y: 3), color: .green)
        )
        let separate = pinnedSamples.pin(
            ImageEditorPreviewPixelSample(point: CGPoint(x: 8, y: 3), color: .blue)
        )
        #expect(first?.number == 1)
        #expect(overlapping?.number == 2)
        #expect(separate?.number == 3)

        let displayedSize = CGSize(width: 100, height: 100)
        let canvasSize = CGSize(width: 10, height: 10)
        #expect(
            pinnedSamples.markerNumber(
                at: CGPoint(x: 25, y: 35),
                displayedSize: displayedSize,
                canvasSize: canvasSize
            ) == 2
        )
        #expect(
            pinnedSamples.markerNumber(
                at: CGPoint(x: 85, y: 35),
                displayedSize: displayedSize,
                canvasSize: canvasSize
            ) == 3
        )
        #expect(
            pinnedSamples.markerNumber(
                at: CGPoint(x: 37, y: 35),
                displayedSize: displayedSize,
                canvasSize: canvasSize
            ) == 2
        )
        #expect(
            pinnedSamples.markerNumber(
                at: CGPoint(x: 38, y: 35),
                displayedSize: displayedSize,
                canvasSize: canvasSize
            ) == nil
        )
        #expect(
            pinnedSamples.markerNumber(
                at: CGPoint(x: 25, y: 35),
                displayedSize: displayedSize,
                canvasSize: canvasSize,
                hitRadius: 0
            ) == nil
        )
        #expect(
            pinnedSamples.markerNumber(
                at: CGPoint(x: CGFloat.infinity, y: 35),
                displayedSize: displayedSize,
                canvasSize: canvasSize
            ) == nil
        )
        #expect(
            pinnedSamples.markerNumber(
                at: CGPoint(x: 25, y: 35),
                displayedSize: .zero,
                canvasSize: canvasSize
            ) == nil
        )
        #expect(pinnedSamples.entries.count == 3)
    }

    @Test func previewMarkerTapActionSeparatesPinSelectAndOptionRemoval() {
        #expect(
            ImageEditorPreviewMarkerTapAction.resolve(
                markerNumber: nil,
                modifierFlags: []
            ) == .pinSample
        )
        #expect(
            ImageEditorPreviewMarkerTapAction.resolve(
                markerNumber: nil,
                modifierFlags: [.option]
            ) == .pinSample
        )
        #expect(
            ImageEditorPreviewMarkerTapAction.resolve(
                markerNumber: 2,
                modifierFlags: []
            ) == .selectDestination(2)
        )
        #expect(
            ImageEditorPreviewMarkerTapAction.resolve(
                markerNumber: 3,
                modifierFlags: [.shift]
            ) == .selectDestination(3)
        )
        #expect(
            ImageEditorPreviewMarkerTapAction.resolve(
                markerNumber: 2,
                modifierFlags: [.option]
            ) == .remove(2)
        )
        #expect(
            ImageEditorPreviewMarkerTapAction.resolve(
                markerNumber: 4,
                modifierFlags: [.option, .command]
            ) == .remove(4)
        )
    }

    @Test func previewPinnedSamplesKeepIndependentColorReadoutModes() {
        var pinnedSamples = ImageEditorPreviewPinnedSamples()
        let firstSample = ImageEditorPreviewPixelSample(
            point: CGPoint(x: 12, y: 8),
            color: NSColor(deviceRed: 1, green: 0.5, blue: 0, alpha: 1)
        )
        let secondSample = ImageEditorPreviewPixelSample(
            point: CGPoint(x: 24, y: 16),
            color: NSColor(deviceRed: 0, green: 0.5, blue: 1, alpha: 0.5)
        )

        let firstPinned = pinnedSamples.pin(firstSample, readoutMode: .rgb)
        let secondPinned = pinnedSamples.pin(secondSample, readoutMode: .cmyk)
        #expect(firstPinned?.readoutMode == .rgb)
        #expect(secondPinned?.readoutMode == .cmyk)
        #expect(pinnedSamples.entries.map(\.readoutMode) == [.rgb, .cmyk])

        let changedFirst = pinnedSamples.setReadoutMode(.hsb, for: 1)
        let unchangedSecond = pinnedSamples.setReadoutMode(.cmyk, for: 2)
        let missingSample = pinnedSamples.setReadoutMode(.hexadecimalRGBA, for: 3)
        #expect(changedFirst)
        #expect(!unchangedSecond)
        #expect(!missingSample)
        #expect(pinnedSamples.entries.map(\.readoutMode) == [.hsb, .cmyk])
        #expect(pinnedSamples.entries[0].sample.point == firstSample.point)
        #expect(pinnedSamples.entries[1].sample.point == secondSample.point)

        let removedFirst = pinnedSamples.remove(number: 1)
        let reusedFirst = pinnedSamples.pin(firstSample, readoutMode: .hexadecimalRGBA)
        #expect(removedFirst)
        #expect(reusedFirst?.number == 1)
        #expect(reusedFirst?.readoutMode == .hexadecimalRGBA)
        #expect(pinnedSamples.entries.map(\.number) == [2, 1])
        #expect(pinnedSamples.entries.map(\.readoutMode) == [.cmyk, .hexadecimalRGBA])
    }

    @Test func previewPinnedSamplesMeasureTheLatestPairInCanvasPixels() throws {
        var pinnedSamples = ImageEditorPreviewPinnedSamples()
        let firstSample = ImageEditorPreviewPixelSample(point: CGPoint(x: 10, y: 10), color: .red)
        let secondSample = ImageEditorPreviewPixelSample(point: CGPoint(x: 13, y: 14), color: .green)
        let thirdSample = ImageEditorPreviewPixelSample(point: CGPoint(x: 7, y: 10), color: .blue)

        #expect(pinnedSamples.latestMeasurement == nil)
        let firstPinned = pinnedSamples.pin(firstSample)
        #expect(firstPinned?.number == 1)
        #expect(pinnedSamples.latestMeasurement == nil)

        let secondPinned = pinnedSamples.pin(secondSample)
        #expect(secondPinned?.number == 2)
        let firstMeasurement = try #require(pinnedSamples.latestMeasurement)
        #expect(firstMeasurement.fromNumber == 1)
        #expect(firstMeasurement.toNumber == 2)
        #expect(firstMeasurement.deltaX == 3)
        #expect(firstMeasurement.deltaY == 4)
        #expect(firstMeasurement.distance == 5)
        #expect(firstMeasurement.deltaXText == "+3")
        #expect(firstMeasurement.deltaYText == "+4")
        #expect(firstMeasurement.distanceText == "5")

        let thirdPinned = pinnedSamples.pin(thirdSample)
        #expect(thirdPinned?.number == 3)
        let latestMeasurement = try #require(pinnedSamples.latestMeasurement)
        #expect(latestMeasurement.fromNumber == 2)
        #expect(latestMeasurement.toNumber == 3)
        #expect(latestMeasurement.deltaXText == "-6")
        #expect(latestMeasurement.deltaYText == "-4")
        #expect(latestMeasurement.distanceText == "7.2")

        let removedSecond = pinnedSamples.remove(number: 2)
        #expect(removedSecond)
        let measurementAfterRemoval = try #require(pinnedSamples.latestMeasurement)
        #expect(measurementAfterRemoval.fromNumber == 1)
        #expect(measurementAfterRemoval.toNumber == 3)
        #expect(measurementAfterRemoval.deltaXText == "-3")
        #expect(measurementAfterRemoval.deltaYText == "0")
        #expect(measurementAfterRemoval.distanceText == "3")

        let invalidSample = ImageEditorPreviewPinnedSample(
            number: 4,
            sample: ImageEditorPreviewPixelSample(
                point: CGPoint(x: CGFloat.infinity, y: 1),
                color: .black
            ),
            readoutMode: .rgb
        )
        #expect(ImageEditorPreviewSampleMeasurement(from: invalidSample, to: invalidSample) == nil)
    }

    @Test func previewPinnedSampleMeasurementSelectsAnyStablePair() throws {
        var pinnedSamples = ImageEditorPreviewPinnedSamples()
        for point in [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 3, y: 4),
            CGPoint(x: 10, y: 10),
            CGPoint(x: 12, y: 15)
        ] {
            let sample = ImageEditorPreviewPixelSample(point: point, color: .black)
            let pinnedSample = pinnedSamples.pin(sample)
            #expect(pinnedSample != nil)
        }

        var selection = ImageEditorPreviewSampleMeasurementSelection()
        let selectedLatest = selection.selectLatest(in: pinnedSamples)
        #expect(selectedLatest)
        #expect(selection.fromNumber == 3)
        #expect(selection.toNumber == 4)

        let selectedFirst = selection.setFrom(1, in: pinnedSamples)
        let selectedSecond = selection.setTo(2, in: pinnedSamples)
        #expect(selectedFirst)
        #expect(selectedSecond)
        #expect(selection.fromNumber == 1)
        #expect(selection.toNumber == 2)
        let manualMeasurement = try #require(selection.measurement(in: pinnedSamples))
        #expect(manualMeasurement.deltaX == 3)
        #expect(manualMeasurement.deltaY == 4)
        #expect(manualMeasurement.distance == 5)

        let swappedEndpoints = selection.setFrom(2, in: pinnedSamples)
        #expect(swappedEndpoints)
        #expect(selection.fromNumber == 2)
        #expect(selection.toNumber == 1)
        let reversedMeasurement = try #require(selection.measurement(in: pinnedSamples))
        #expect(reversedMeasurement.deltaX == -3)
        #expect(reversedMeasurement.deltaY == -4)

        let rejectedMissing = selection.setTo(99, in: pinnedSamples)
        #expect(!rejectedMissing)
        #expect(selection.fromNumber == 2)
        #expect(selection.toNumber == 1)

        let removedSelected = pinnedSamples.remove(number: 2)
        let reconciled = selection.reconcile(in: pinnedSamples)
        #expect(removedSelected)
        #expect(reconciled)
        #expect(selection.fromNumber == 3)
        #expect(selection.toNumber == 4)

        pinnedSamples.removeAll()
        let clearedSelection = selection.reconcile(in: pinnedSamples)
        #expect(clearedSelection)
        #expect(selection.fromNumber == nil)
        #expect(selection.toNumber == nil)
        #expect(selection.measurement(in: pinnedSamples) == nil)
    }

    @Test func previewMeasurementCopiesEndpointsAndValuesToClipboard() throws {
        var pinnedSamples = ImageEditorPreviewPinnedSamples()
        _ = pinnedSamples.pin(
            ImageEditorPreviewPixelSample(point: CGPoint(x: 10, y: 20), color: .red)
        )
        _ = pinnedSamples.pin(
            ImageEditorPreviewPixelSample(point: CGPoint(x: 13, y: 24), color: .blue)
        )
        let measurement = try #require(pinnedSamples.latestMeasurement)
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("xomo-tests.preview-measurement-copy.\(UUID().uuidString)")
        )

        let copied = measurement.copy(to: pasteboard)

        #expect(copied)
        #expect(pasteboard.string(forType: .string) == measurement.text)
        #expect(measurement.text.contains("#1"))
        #expect(measurement.text.contains("#2"))
        #expect(measurement.text.contains(measurement.deltaXText))
        #expect(measurement.text.contains(measurement.deltaYText))
        #expect(measurement.text.contains(measurement.distanceText))
    }

    @Test func previewMarkerClicksAdvanceMeasurementDestinationInVisualOrder() {
        var pinnedSamples = ImageEditorPreviewPinnedSamples()
        for offset in 0..<4 {
            let pinned = pinnedSamples.pin(
                ImageEditorPreviewPixelSample(
                    point: CGPoint(x: offset, y: offset),
                    color: .black
                )
            )
            #expect(pinned != nil)
        }

        var selection = ImageEditorPreviewSampleMeasurementSelection()
        let selectedLatest = selection.selectLatest(in: pinnedSamples)
        #expect(selectedLatest)
        #expect(selection.fromNumber == 3)
        #expect(selection.toNumber == 4)

        let selectedFirst = selection.selectDestination(1, in: pinnedSamples)
        #expect(selectedFirst)
        #expect(selection.fromNumber == 4)
        #expect(selection.toNumber == 1)

        let selectedSecond = selection.selectDestination(2, in: pinnedSamples)
        #expect(selectedSecond)
        #expect(selection.fromNumber == 1)
        #expect(selection.toNumber == 2)

        let reversedToFirst = selection.selectDestination(1, in: pinnedSamples)
        #expect(reversedToFirst)
        #expect(selection.fromNumber == 2)
        #expect(selection.toNumber == 1)

        let unchangedDestination = selection.selectDestination(1, in: pinnedSamples)
        let rejectedMissing = selection.selectDestination(99, in: pinnedSamples)
        #expect(!unchangedDestination)
        #expect(!rejectedMissing)
        #expect(selection.fromNumber == 2)
        #expect(selection.toNumber == 1)

        var singleSample = ImageEditorPreviewPinnedSamples()
        let onlySample = singleSample.pin(
            ImageEditorPreviewPixelSample(point: .zero, color: .black)
        )
        #expect(onlySample != nil)
        var emptySelection = ImageEditorPreviewSampleMeasurementSelection()
        let rejectedSingle = emptySelection.selectDestination(1, in: singleSample)
        #expect(!rejectedSingle)
        #expect(emptySelection.fromNumber == nil)
        #expect(emptySelection.toNumber == nil)
    }

    @Test func previewSelectedMeasurementMapsGuideAcrossZoomLevels() throws {
        var pinnedSamples = ImageEditorPreviewPinnedSamples()
        let firstPinned = pinnedSamples.pin(
            ImageEditorPreviewPixelSample(point: CGPoint(x: 1, y: 2), color: .black)
        )
        let secondPinned = pinnedSamples.pin(
            ImageEditorPreviewPixelSample(point: CGPoint(x: 4, y: 6), color: .white)
        )
        #expect(firstPinned != nil)
        #expect(secondPinned != nil)

        var selection = ImageEditorPreviewSampleMeasurementSelection()
        let selectedLatest = selection.selectLatest(in: pinnedSamples)
        #expect(selectedLatest)
        let canvasSize = CGSize(width: 10, height: 10)
        let fitGuide = try #require(
            ImageEditorPreviewSampleMeasurementGuide(
                selection: selection,
                samples: pinnedSamples,
                displayedSize: CGSize(width: 100, height: 200),
                canvasSize: canvasSize
            )
        )
        #expect(fitGuide.fromCenter == CGPoint(x: 15, y: 50))
        #expect(fitGuide.toCenter == CGPoint(x: 45, y: 130))
        #expect(fitGuide.midpoint == CGPoint(x: 30, y: 90))
        #expect(fitGuide.orthogonalCorner == CGPoint(x: 45, y: 50))
        #expect(fitGuide.horizontalMidpoint == CGPoint(x: 30, y: 50))
        #expect(fitGuide.verticalMidpoint == CGPoint(x: 45, y: 90))
        #expect(fitGuide.showsOrthogonalComponents)
        #expect(fitGuide.distanceLabelCenter == fitGuide.midpoint)
        #expect(fitGuide.horizontalLabelCenter == nil)
        #expect(fitGuide.verticalLabelCenter == fitGuide.verticalMidpoint)
        #expect(fitGuide.measurement.distance == 5)

        let doubleGuide = try #require(
            ImageEditorPreviewSampleMeasurementGuide(
                selection: selection,
                samples: pinnedSamples,
                displayedSize: CGSize(width: 200, height: 400),
                canvasSize: canvasSize
            )
        )
        #expect(doubleGuide.fromCenter == CGPoint(x: 30, y: 100))
        #expect(doubleGuide.toCenter == CGPoint(x: 90, y: 260))
        #expect(doubleGuide.midpoint == CGPoint(x: 60, y: 180))
        #expect(doubleGuide.horizontalLabelCenter == CGPoint(x: 60, y: 100))
        #expect(doubleGuide.verticalLabelCenter == CGPoint(x: 90, y: 180))
        #expect(doubleGuide.measurement.distance == 5)

        let reversedSelection = selection.setFrom(2, in: pinnedSamples)
        #expect(reversedSelection)
        let reversedGuide = try #require(
            ImageEditorPreviewSampleMeasurementGuide(
                selection: selection,
                samples: pinnedSamples,
                displayedSize: CGSize(width: 100, height: 200),
                canvasSize: canvasSize
            )
        )
        #expect(reversedGuide.fromCenter == fitGuide.toCenter)
        #expect(reversedGuide.toCenter == fitGuide.fromCenter)
        #expect(reversedGuide.measurement.deltaX == -3)
        #expect(reversedGuide.measurement.deltaY == -4)

        #expect(
            ImageEditorPreviewSampleMeasurementGuide(
                selection: selection,
                samples: pinnedSamples,
                displayedSize: .zero,
                canvasSize: canvasSize
            ) == nil
        )
        selection.reset()
        #expect(
            ImageEditorPreviewSampleMeasurementGuide(
                selection: selection,
                samples: pinnedSamples,
                displayedSize: CGSize(width: 100, height: 200),
                canvasSize: canvasSize
            ) == nil
        )
    }

    @Test func previewMeasurementGuideAdaptsLabelsAndAxisAlignedPairs() throws {
        var diagonalSamples = ImageEditorPreviewPinnedSamples()
        let diagonalFirst = diagonalSamples.pin(
            ImageEditorPreviewPixelSample(point: CGPoint(x: 1, y: 2), color: .black)
        )
        let diagonalSecond = diagonalSamples.pin(
            ImageEditorPreviewPixelSample(point: CGPoint(x: 4, y: 6), color: .white)
        )
        #expect(diagonalFirst != nil)
        #expect(diagonalSecond != nil)
        var diagonalSelection = ImageEditorPreviewSampleMeasurementSelection()
        let selectedDiagonal = diagonalSelection.selectLatest(in: diagonalSamples)
        #expect(selectedDiagonal)
        let compactGuide = try #require(
            ImageEditorPreviewSampleMeasurementGuide(
                selection: diagonalSelection,
                samples: diagonalSamples,
                displayedSize: CGSize(width: 20, height: 40),
                canvasSize: CGSize(width: 10, height: 10)
            )
        )
        #expect(compactGuide.showsOrthogonalComponents)
        #expect(compactGuide.distanceLabelCenter == nil)
        #expect(compactGuide.horizontalLabelCenter == nil)
        #expect(compactGuide.verticalLabelCenter == nil)

        var axisSamples = ImageEditorPreviewPinnedSamples()
        let axisFirst = axisSamples.pin(
            ImageEditorPreviewPixelSample(point: CGPoint(x: 1, y: 2), color: .black)
        )
        let axisSecond = axisSamples.pin(
            ImageEditorPreviewPixelSample(point: CGPoint(x: 4, y: 2), color: .white)
        )
        #expect(axisFirst != nil)
        #expect(axisSecond != nil)
        var axisSelection = ImageEditorPreviewSampleMeasurementSelection()
        let selectedAxis = axisSelection.selectLatest(in: axisSamples)
        #expect(selectedAxis)
        let axisGuide = try #require(
            ImageEditorPreviewSampleMeasurementGuide(
                selection: axisSelection,
                samples: axisSamples,
                displayedSize: CGSize(width: 200, height: 200),
                canvasSize: CGSize(width: 10, height: 10)
            )
        )
        #expect(!axisGuide.showsOrthogonalComponents)
        #expect(axisGuide.orthogonalCorner == axisGuide.toCenter)
        #expect(axisGuide.distanceLabelCenter == axisGuide.midpoint)
        #expect(axisGuide.horizontalLabelCenter == nil)
        #expect(axisGuide.verticalLabelCenter == nil)
    }

    @Test func previewPixelInspectionAveragesNeighborhoodAndClipsCanvasEdges() throws {
        let canvasSize = CGSize(width: 3, height: 1)
        let image = try #require(NSImage.rendered(size: canvasSize) { _ in
            NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1).setFill()
            CGRect(x: 0, y: 0, width: 1, height: 1).fill()
            NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1).setFill()
            CGRect(x: 1, y: 0, width: 1, height: 1).fill()
            NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1).setFill()
            CGRect(x: 2, y: 0, width: 1, height: 1).fill()
        })

        let point = try #require(
            ImageEditorPreviewPixelSample.sample(
                image: image,
                location: CGPoint(x: 1.5, y: 0.5),
                displayedSize: canvasSize,
                canvasSize: canvasSize,
                sampleSize: .point
            )
        )
        let average3 = try #require(
            ImageEditorPreviewPixelSample.sample(
                image: image,
                location: CGPoint(x: 1.5, y: 0.5),
                displayedSize: canvasSize,
                canvasSize: canvasSize,
                sampleSize: .average3
            )
        )
        let average5 = try #require(
            ImageEditorPreviewPixelSample.sample(
                image: image,
                location: CGPoint(x: 1.5, y: 0.5),
                displayedSize: canvasSize,
                canvasSize: canvasSize,
                sampleSize: .average5
            )
        )
        let edgeAverage = try #require(
            ImageEditorPreviewPixelSample.sample(
                image: image,
                location: CGPoint(x: 0.5, y: 0.5),
                displayedSize: canvasSize,
                canvasSize: canvasSize,
                sampleSize: .average3
            )
        )

        #expect(point.text.contains("#00FF00FF"))
        #expect(average3.text.contains("#555555FF"))
        #expect(average5.text.contains("#555555FF"))
        #expect(edgeAverage.text.contains("#808000FF"))
        #expect(ImageEditorPreviewPixelSampleSize.allCases.map(\.rawValue) == [1, 3, 5])
    }

    @Test func changingPreviewSampleSizeResamplesWithoutLosingPinnedMeasurementState() throws {
        let canvasSize = CGSize(width: 3, height: 1)
        let image = try #require(NSImage.rendered(size: canvasSize) { _ in
            NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1).setFill()
            CGRect(x: 0, y: 0, width: 1, height: 1).fill()
            NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1).setFill()
            CGRect(x: 1, y: 0, width: 1, height: 1).fill()
            NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1).setFill()
            CGRect(x: 2, y: 0, width: 1, height: 1).fill()
        })
        let first = try #require(ImageEditorPreviewPixelSample.sample(
            image: image,
            canvasPoint: CGPoint(x: 0, y: 0),
            canvasSize: canvasSize
        ))
        let second = try #require(ImageEditorPreviewPixelSample.sample(
            image: image,
            canvasPoint: CGPoint(x: 1, y: 0),
            canvasSize: canvasSize
        ))
        var pinnedSamples = ImageEditorPreviewPinnedSamples()
        _ = pinnedSamples.pin(first, readoutMode: .rgb)
        _ = pinnedSamples.pin(second, readoutMode: .cmyk)
        var measurementSelection = ImageEditorPreviewSampleMeasurementSelection()
        let didSelectLatest = measurementSelection.selectLatest(in: pinnedSamples)
        #expect(didSelectLatest)

        let updatedCount = pinnedSamples.resample(
            image: image,
            canvasSize: canvasSize,
            sampleSize: .average3
        )

        #expect(updatedCount == 2)
        #expect(pinnedSamples.entries.map(\.number) == [1, 2])
        #expect(pinnedSamples.entries.map(\.readoutMode) == [.rgb, .cmyk])
        #expect(pinnedSamples.entries.map(\.sample.point) == [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0)
        ])
        #expect(pinnedSamples.entries[0].sample.text.contains("#808000FF"))
        #expect(pinnedSamples.entries[1].sample.text.contains("#555555FF"))
        let measurement = try #require(
            measurementSelection.measurement(in: pinnedSamples)
        )
        #expect(measurement.fromNumber == 1)
        #expect(measurement.toNumber == 2)
        #expect(measurement.deltaX == 1)
        #expect(measurement.deltaY == 0)
    }

    @Test func pureVectorCanvasExportsEditableSVG() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "vector-canvas",
            image: NSImage.transparent(size: CGSize(width: 320, height: 180))
        ) { _ in }
        viewModel.document.layers.append(
            .shape(
                name: "Card",
                frame: CGRect(x: 24, y: 28, width: 180, height: 80),
                content: ImageEditorShapeContent(
                    kind: .rectangle,
                    fillColor: .systemBlue,
                    fillOpacity: 1,
                    strokeColor: .white,
                    strokeWidth: 2,
                    strokeOpacity: 1
                )
            )
        )
        viewModel.document.layers.append(
            .text(
                name: "Title",
                origin: CGPoint(x: 40, y: 54),
                content: ImageEditorTextContent(
                    text: "Xomo",
                    color: .white,
                    fontSize: 20,
                    point: .zero,
                    isBold: true
                )
            )
        )

        #expect(viewModel.canExportSVG)
        let svg = try #require(viewModel.exportData(settings: ImageEditorExportSettings(format: .svg)))
        let source = try #require(String(data: svg, encoding: .utf8))
        #expect(source.contains("<svg"))
        #expect(source.contains("<rect"))
        #expect(source.contains("<text"))
        #expect(!source.contains("<image"))
    }

    @Test func editableSVGPreservesOpenPathMarkersAndAdvancedStrokeStyle() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "marker-canvas",
            image: NSImage.transparent(size: CGSize(width: 320, height: 180))
        ) { _ in }
        let decorations: [(ImageEditorStrokeDecoration, ImageEditorStrokeDecoration)] = [
            (.openArrow, .filledArrow),
            (.filledTriangle, .filledDiamond),
            (.filledCircle, .none)
        ]
        for (index, pair) in decorations.enumerated() {
            let content = ImageEditorShapeContent(
                kind: .path,
                fillColor: .clear,
                fillOpacity: 0,
                strokeColor: .systemBlue,
                strokeWidth: 4,
                strokeOpacity: 0.75,
                strokeCap: .square,
                strokeStartDecoration: pair.0,
                strokeEndDecoration: pair.1,
                strokeJoin: .bevel,
                strokeMiterLimit: 7,
                strokeDashPattern: [8, 4],
                strokeDashOffset: 3.5,
                pathAnchors: [
                    ImageEditorPathAnchor(point: CGPoint(x: 20, y: 20)),
                    ImageEditorPathAnchor(point: CGPoint(x: 180, y: 52))
                ],
                isPathClosed: false
            )
            viewModel.document.layers.append(
                .shape(
                    name: "Marker \(index)",
                    frame: CGRect(x: 30, y: CGFloat(index * 48), width: 200, height: 72),
                    content: content
                )
            )
        }

        let data = try #require(
            viewModel.exportData(settings: ImageEditorExportSettings(format: .svg))
        )
        let source = try #require(String(data: data, encoding: .utf8))
        let xml = try XMLDocument(data: data, options: [])
        #expect(xml.rootElement()?.name == "svg")
        #expect(source.contains("<marker"))
        #expect(source.contains("marker-start=\"url(#xomo-marker-start-"))
        #expect(source.contains("marker-end=\"url(#xomo-marker-end-"))
        #expect(source.contains("orient=\"auto-start-reverse\""))
        for decoration in ImageEditorStrokeDecoration.allCases where decoration != .none {
            #expect(source.contains("data-xomo-decoration=\"\(decoration.rawValue)\""))
        }
        #expect(source.contains("stroke-linecap=\"square\""))
        #expect(source.contains("stroke-linejoin=\"bevel\""))
        #expect(source.contains("stroke-miterlimit=\"7\""))
        #expect(source.contains("stroke-dasharray=\"8 4\""))
        #expect(source.contains("stroke-dashoffset=\"3.500\""))
        #expect(!source.contains("<image"))
    }

    @Test func editableSVGDoesNotAttachEndpointMarkersToClosedPaths() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "closed-marker-canvas",
            image: NSImage.transparent(size: CGSize(width: 160, height: 120))
        ) { _ in }
        viewModel.document.layers.append(
            .shape(
                name: "Closed path",
                frame: CGRect(x: 20, y: 20, width: 100, height: 80),
                content: ImageEditorShapeContent(
                    kind: .path,
                    fillColor: .systemYellow,
                    fillOpacity: 1,
                    strokeColor: .black,
                    strokeWidth: 3,
                    strokeOpacity: 1,
                    strokeStartDecoration: .filledCircle,
                    strokeEndDecoration: .openArrow,
                    pathAnchors: [
                        ImageEditorPathAnchor(point: CGPoint(x: 10, y: 10)),
                        ImageEditorPathAnchor(point: CGPoint(x: 90, y: 12)),
                        ImageEditorPathAnchor(point: CGPoint(x: 52, y: 68))
                    ],
                    isPathClosed: true
                )
            )
        )

        let data = try #require(
            viewModel.exportData(settings: ImageEditorExportSettings(format: .svg))
        )
        let source = try #require(String(data: data, encoding: .utf8))
        let xml = try XMLDocument(data: data, options: [])
        #expect(xml.rootElement()?.name == "svg")
        #expect(!source.contains("<marker"))
        #expect(!source.contains("marker-start="))
        #expect(!source.contains("marker-end="))
        #expect(source.contains(" Z\""))
    }

    @Test func mixedCanvasExportsPDFAndRejectsSVG() throws {
        let rasterImage = try #require(
            NSImage.rendered(size: CGSize(width: 96, height: 64)) { rect in
                NSColor.systemOrange.setFill()
                rect.fill()
            }
        )
        let viewModel = ImageEditorViewModel(sourceName: "mixed-canvas", image: rasterImage) { _ in }

        #expect(!viewModel.canExportSVG)
        #expect(viewModel.exportData(settings: ImageEditorExportSettings(format: .svg)) == nil)

        let pdf = try #require(viewModel.exportData(settings: ImageEditorExportSettings(format: .pdf)))
        #expect(String(data: pdf.prefix(4), encoding: .ascii) == "%PDF")
        let renderedPDF = try #require(NSImage(data: pdf))
        #expect(renderedPDF.size == rasterImage.size)
        #expect(renderedPDF.nonTransparentPixelBounds() != nil)
    }

    @Test func exportNamingRulesSupportBatchScaleVariants() {
        let viewModel = ImageEditorViewModel(
            sourceName: "landing.png",
            image: NSImage.transparent(size: CGSize(width: 120, height: 80))
        ) { _ in }
        let batchSettings = ImageEditorExportSettings(
            format: .png,
            scope: .composited,
            scale: 1,
            batchScales: [2, 3],
            namingRule: .sourceScopeAndScale
        )

        #expect(viewModel.exportFilenames(settings: batchSettings) == [
            "landing-edited@1x.png",
            "landing-edited@2x.png",
            "landing-edited@3x.png"
        ])

        let sourceOnly = ImageEditorExportSettings(
            format: .png,
            scope: .composited,
            scale: 1,
            namingRule: .sourceName
        )
        #expect(viewModel.exportFilenames(settings: sourceOnly) == ["landing.png"])

        let pdfSettings = ImageEditorExportSettings(
            format: .pdf,
            scope: .composited,
            scale: 1,
            batchScales: [2, 3]
        )
        #expect(viewModel.exportFilenames(settings: pdfSettings) == ["landing-edited.pdf"])
    }

    @Test func selectionScopeExportsASelectionSliceBoundedByTheSelectionAndPreservesTransparency() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "landing.png",
            image: NSImage.rendered(size: CGSize(width: 80, height: 60)) { rect in
                NSColor.systemBlue.setFill()
                rect.fill()
            }!
        ) { _ in }
        viewModel.document.selection = try #require(
            ImageEditorSelection.ellipse(CGRect(x: 20, y: 10, width: 40, height: 30))
        )

        #expect(viewModel.canExportSelection)
        let settings = ImageEditorExportSettings(format: .png, scope: .selection)
        let data = try #require(viewModel.exportData(settings: settings))
        let exported = try #require(NSImage(data: data))
        let center = try #require(exported.color(at: CGPoint(x: 20, y: 15))?.usingColorSpace(.deviceRGB))
        let corner = try #require(exported.color(at: CGPoint(x: 1, y: 1))?.usingColorSpace(.deviceRGB))

        #expect(exported.size == CGSize(width: 40, height: 30))
        #expect(center.blueComponent > 0.7)
        #expect(center.alphaComponent > 0.8)
        #expect(corner.alphaComponent < 0.1)
        #expect(viewModel.exportFilenames(settings: settings) == ["landing-selection.png"])
    }

    @Test func namedSliceScopeExportsTheNamedRectangularCanvasRegion() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "landing.png",
            image: NSImage.rendered(size: CGSize(width: 80, height: 60)) { rect in
                NSColor.systemBlue.setFill()
                rect.fill()
            }!
        ) { _ in }
        let slice = ImageEditorSlice(
            name: "Hero",
            frame: CGRect(x: 20, y: 10, width: 40, height: 30)
        )
        viewModel.document.slices = [slice]

        let settings = ImageEditorExportSettings(
            format: .png,
            scope: .slice,
            sliceID: slice.id
        )
        let data = try #require(viewModel.exportData(settings: settings))
        let exported = try #require(NSImage(data: data))

        #expect(exported.size == CGSize(width: 40, height: 30))
        #expect(exported.color(at: CGPoint(x: 20, y: 15))?.alphaComponent ?? 0 > 0.8)
        #expect(viewModel.exportFilenames(settings: settings) == ["Hero.png"])
    }

    @Test func addingCurrentSliceExportPresetIsUndoableAndIdempotent() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "delivery.png",
            image: NSImage.transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }
        let slice = ImageEditorSlice(
            name: "Hero",
            frame: CGRect(x: 10, y: 10, width: 40, height: 30)
        )
        viewModel.document.slices = [slice]
        viewModel.exportSettings = ImageEditorExportSettings(
            format: .png,
            scope: .slice,
            sliceID: slice.id,
            scale: 2,
            filenameSuffix: "-stale-imported-suffix"
        )
        let historyCount = viewModel.document.history.count

        #expect(viewModel.addCurrentExportPreset(toSlice: slice.id))
        #expect(viewModel.document.slices.first?.exportPresets == [
            ImageEditorSliceExportPreset(
                suffix: "@2x",
                format: .png,
                constraint: .scale,
                value: 2
            )
        ])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.canUndo)

        let historyAfterAdd = viewModel.document.history.count
        #expect(!viewModel.addCurrentExportPreset(toSlice: slice.id))
        #expect(viewModel.document.history.count == historyAfterAdd)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.sliceExportPresetUnchanged"))

        viewModel.undo()
        #expect(viewModel.document.slices.first?.exportPresets == nil)
        #expect(viewModel.canRedo)
        viewModel.redo()
        #expect(viewModel.document.slices.first?.exportPresets?.first?.suffix == "@2x")
    }

    @Test func removingSliceExportPresetUpdatesPrimarySettingAndIsUndoable() {
        let viewModel = ImageEditorViewModel(
            sourceName: "delivery.png",
            image: NSImage.transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }
        let presets = [
            ImageEditorSliceExportPreset(
                suffix: "@2x",
                format: .png,
                constraint: .scale,
                value: 2
            ),
            ImageEditorSliceExportPreset(
                suffix: "-print",
                format: .pdf,
                constraint: .scale,
                value: 1
            )
        ]
        let slice = ImageEditorSlice(
            name: "Hero",
            frame: CGRect(x: 10, y: 10, width: 40, height: 30),
            exportPresets: presets
        )
        viewModel.document.slices = [slice]
        _ = viewModel.selectSlice(id: slice.id)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.removeSliceExportPreset(fromSlice: slice.id, at: 0))
        #expect(viewModel.document.slices.first?.exportPresets == [presets[1]])
        #expect(viewModel.exportSettings.format == .pdf)
        #expect(viewModel.exportSettings.filenameSuffix == "-print")
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.slices.first?.exportPresets == presets)
        #expect(viewModel.canRedo)
        viewModel.redo()
        #expect(viewModel.document.slices.first?.exportPresets == [presets[1]])
    }

    @Test func sliceExportPresetBoundariesDoNotCreateTransactions() {
        let viewModel = ImageEditorViewModel(
            sourceName: "delivery.png",
            image: NSImage.transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }
        let slice = ImageEditorSlice(
            name: "Hero",
            frame: CGRect(x: 10, y: 10, width: 40, height: 30)
        )
        viewModel.document.slices = [slice]
        let originalHistory = viewModel.document.history
        let originalCanUndo = viewModel.canUndo

        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = slice.id
        viewModel.exportSettings.format = .webp
        #expect(!viewModel.addCurrentExportPreset(toSlice: slice.id))
        #expect(viewModel.document.slices.first?.exportPresets == nil)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.sliceExportPresetUnsupported"))

        viewModel.exportSettings.format = .png
        viewModel.exportSettings.scale = 5
        #expect(!viewModel.addCurrentExportPreset(toSlice: slice.id))
        #expect(viewModel.document.slices.first?.exportPresets == nil)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.sliceExportPresetInvalid"))

        viewModel.document.slices[0].exportPresets = (0..<ImageEditorSlice.maximumExportPresetCount).map { index in
            ImageEditorSliceExportPreset(
                suffix: "-\(index)",
                format: .png,
                constraint: .scale,
                value: 1
            )
        }
        viewModel.exportSettings.scale = 1
        viewModel.exportSettings.filenameSuffix = "-extra"
        let fullPresets = viewModel.document.slices[0].exportPresets
        #expect(!viewModel.addCurrentExportPreset(toSlice: slice.id))
        #expect(viewModel.document.slices[0].exportPresets == fullPresets)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.sliceExportPresetLimitReached"))
        #expect(viewModel.document.history == originalHistory)
        #expect(viewModel.canUndo == originalCanUndo)
    }

    @Test func reorderingSliceExportPresetsUpdatesDeliveryOrderAndHistorySelection() {
        let viewModel = ImageEditorViewModel(
            sourceName: "delivery.png",
            image: NSImage.transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }
        let presets = [
            ImageEditorSliceExportPreset(
                suffix: "@2x",
                format: .png,
                constraint: .scale,
                value: 2
            ),
            ImageEditorSliceExportPreset(
                suffix: "@3x",
                format: .jpeg,
                constraint: .scale,
                value: 3
            ),
            ImageEditorSliceExportPreset(
                suffix: "-print",
                format: .pdf,
                constraint: .scale,
                value: 1
            )
        ]
        let slice = ImageEditorSlice(
            name: "Hero",
            frame: CGRect(x: 10, y: 10, width: 40, height: 30),
            exportPresets: presets
        )
        viewModel.document.slices = [slice]
        _ = viewModel.selectSlice(id: slice.id)
        let historyCount = viewModel.document.history.count

        #expect(!viewModel.moveSliceExportPreset(inSlice: slice.id, from: 0, direction: .up))
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.moveSliceExportPreset(inSlice: slice.id, from: 1, direction: .up))
        #expect(viewModel.document.slices[0].exportPresets == [presets[1], presets[0], presets[2]])
        #expect(viewModel.exportSettings.format == .jpeg)
        #expect(viewModel.exportSettings.scale == 3)
        #expect(viewModel.sliceExportPlan(settings: viewModel.exportSettings).map(\.filename) == [
            "Hero@3x.jpg",
            "Hero@2x.png",
            "Hero-print.pdf"
        ])
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.slices[0].exportPresets == presets)
        #expect(viewModel.exportSettings.format == .png)
        #expect(viewModel.exportSettings.scale == 2)
        viewModel.redo()
        #expect(viewModel.document.slices[0].exportPresets == [presets[1], presets[0], presets[2]])
        #expect(viewModel.exportSettings.format == .jpeg)

        #expect(viewModel.moveSliceExportPreset(inSlice: slice.id, from: 0, direction: .down))
        #expect(viewModel.document.slices[0].exportPresets == presets)
        #expect(viewModel.exportSettings.format == .png)

        viewModel.exportSettings.scale = 3.5
        viewModel.exportSettings.filenameSuffix = "@3.5x"
        viewModel.syncExportSettingsAfterSliceHistoryChange(from: viewModel.document.slices)
        #expect(viewModel.exportSettings.scale == 3.5)
        #expect(viewModel.exportSettings.filenameSuffix == "@3.5x")
    }

    @Test func editingSliceExportPresetSuffixSanitizesDeduplicatesAndRoundTripsHistory() {
        let viewModel = ImageEditorViewModel(
            sourceName: "delivery.png",
            image: NSImage.transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }
        let presets = [
            ImageEditorSliceExportPreset(
                suffix: "@2x",
                format: .png,
                constraint: .scale,
                value: 2
            ),
            ImageEditorSliceExportPreset(
                suffix: "-alternate",
                format: .png,
                constraint: .scale,
                value: 2
            )
        ]
        let slice = ImageEditorSlice(
            name: "Hero",
            frame: CGRect(x: 10, y: 10, width: 40, height: 30),
            exportPresets: presets
        )
        viewModel.document.slices = [slice]
        _ = viewModel.selectSlice(id: slice.id)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.updateSliceExportPresetSuffix(
            inSlice: slice.id,
            at: 0,
            suffix: "/../dark"
        ))
        #expect(viewModel.document.slices[0].exportPresets?.first?.suffix == "-..-dark")
        #expect(viewModel.exportSettings.filenameSuffix == "-..-dark")
        #expect(viewModel.sliceExportPlan(settings: viewModel.exportSettings).first?.filename == "Hero-..-dark.png")
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.slices[0].exportPresets == presets)
        #expect(viewModel.exportSettings.filenameSuffix == "@2x")
        viewModel.redo()
        #expect(viewModel.document.slices[0].exportPresets?.first?.suffix == "-..-dark")
        #expect(viewModel.exportSettings.filenameSuffix == "-..-dark")

        let historyAfterEdit = viewModel.document.history.count
        #expect(!viewModel.updateSliceExportPresetSuffix(
            inSlice: slice.id,
            at: 0,
            suffix: "/../dark"
        ))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.sliceExportPresetUnchanged"))
        #expect(viewModel.document.history.count == historyAfterEdit)

        #expect(!viewModel.updateSliceExportPresetSuffix(
            inSlice: slice.id,
            at: 1,
            suffix: "-..-dark"
        ))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.sliceExportPresetDuplicate"))
        #expect(viewModel.document.history.count == historyAfterEdit)
        #expect(!viewModel.updateSliceExportPresetSuffix(
            inSlice: slice.id,
            at: 99,
            suffix: "-missing"
        ))
        #expect(viewModel.document.history.count == historyAfterEdit)
    }

    @Test func editingSliceExportPresetFormatNormalizesPDFDeduplicatesAndRoundTripsHistory() {
        let viewModel = ImageEditorViewModel(
            sourceName: "delivery.png",
            image: NSImage.transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }
        let presets = [
            ImageEditorSliceExportPreset(
                suffix: "@2x",
                format: .png,
                constraint: .scale,
                value: 2
            ),
            ImageEditorSliceExportPreset(
                suffix: "-web",
                format: .jpeg,
                constraint: .scale,
                value: 3
            ),
            ImageEditorSliceExportPreset(
                suffix: "-web",
                format: .pdf,
                constraint: .scale,
                value: 1
            )
        ]
        let slice = ImageEditorSlice(
            name: "Hero",
            frame: CGRect(x: 10, y: 10, width: 40, height: 30),
            exportPresets: presets
        )
        viewModel.document.slices = [slice]
        _ = viewModel.selectSlice(id: slice.id)
        let historyCount = viewModel.document.history.count

        #expect(ImageEditorExportFormat.sliceExportPresetFormats == [.png, .jpeg, .pdf])
        #expect(viewModel.updateSliceExportPresetFormat(
            inSlice: slice.id,
            at: 0,
            format: .pdf
        ))
        let updated = viewModel.document.slices[0].exportPresets?.first
        #expect(updated?.format == .pdf)
        #expect(updated?.constraint == .scale)
        #expect(updated?.value == 1)
        #expect(updated?.suffix == "@2x")
        #expect(viewModel.exportSettings.format == .pdf)
        #expect(viewModel.exportSettings.scale == 1)
        #expect(viewModel.exportSettings.filenameSuffix == "@2x")
        #expect(viewModel.sliceExportPlan(settings: viewModel.exportSettings).first?.filename == "Hero@2x.pdf")
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.slices[0].exportPresets == presets)
        #expect(viewModel.exportSettings.format == .png)
        #expect(viewModel.exportSettings.scale == 2)
        viewModel.redo()
        #expect(viewModel.document.slices[0].exportPresets?.first == updated)
        #expect(viewModel.exportSettings.format == .pdf)

        let historyAfterEdit = viewModel.document.history.count
        #expect(!viewModel.updateSliceExportPresetFormat(
            inSlice: slice.id,
            at: 1,
            format: .pdf
        ))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.sliceExportPresetDuplicate"))
        #expect(viewModel.document.history.count == historyAfterEdit)
        #expect(!viewModel.updateSliceExportPresetFormat(
            inSlice: slice.id,
            at: 0,
            format: .webp
        ))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.sliceExportPresetUnsupported"))
        #expect(viewModel.document.history.count == historyAfterEdit)
        #expect(!viewModel.updateSliceExportPresetFormat(
            inSlice: slice.id,
            at: 0,
            format: .pdf
        ))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.sliceExportPresetUnchanged"))
        #expect(viewModel.document.history.count == historyAfterEdit)
        #expect(!viewModel.updateSliceExportPresetFormat(
            inSlice: slice.id,
            at: 99,
            format: .jpeg
        ))
        #expect(viewModel.document.history.count == historyAfterEdit)
    }

    @Test func editingSliceExportPresetDeliveryPreservesScaleValidatesAndRoundTripsHistory() {
        let viewModel = ImageEditorViewModel(
            sourceName: "delivery.png",
            image: NSImage.transparent(size: CGSize(width: 160, height: 100))
        ) { _ in }
        let presets = [
            ImageEditorSliceExportPreset(
                suffix: "@2x",
                format: .png,
                constraint: .scale,
                value: 2
            ),
            ImageEditorSliceExportPreset(
                suffix: "@2x",
                format: .png,
                constraint: .width,
                value: 300
            ),
            ImageEditorSliceExportPreset(
                suffix: "-print",
                format: .pdf,
                constraint: .scale,
                value: 1
            )
        ]
        let slice = ImageEditorSlice(
            name: "Hero",
            frame: CGRect(x: 10, y: 10, width: 100, height: 50),
            exportPresets: presets
        )
        viewModel.document.slices = [slice]
        _ = viewModel.selectSlice(id: slice.id)
        let historyCount = viewModel.document.history.count

        #expect(ImageEditorSliceExportConstraint.allCases == [.scale, .width, .height])
        #expect(viewModel.changeSliceExportPresetConstraint(
            inSlice: slice.id,
            at: 0,
            to: .width
        ))
        var updated = viewModel.document.slices[0].exportPresets?[0]
        #expect(updated?.constraint == .width)
        #expect(updated?.value == 200)
        #expect(viewModel.exportSettings.scale == 2)
        #expect(viewModel.document.history.count == historyCount + 1)

        let historyAfterConstraint = viewModel.document.history.count
        #expect(!viewModel.changeSliceExportPresetConstraint(
            inSlice: slice.id,
            at: 0,
            to: .width
        ))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.sliceExportPresetUnchanged"))
        #expect(viewModel.document.history.count == historyAfterConstraint)
        #expect(!viewModel.updateSliceExportPresetValue(
            inSlice: slice.id,
            at: 0,
            value: 300
        ))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.sliceExportPresetDuplicate"))
        #expect(viewModel.document.history.count == historyAfterConstraint)
        #expect(!viewModel.updateSliceExportPresetValue(
            inSlice: slice.id,
            at: 0,
            value: 1_000
        ))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.sliceExportPresetInvalid"))
        #expect(viewModel.document.history.count == historyAfterConstraint)

        #expect(viewModel.updateSliceExportPresetValue(
            inSlice: slice.id,
            at: 0,
            value: 250
        ))
        updated = viewModel.document.slices[0].exportPresets?[0]
        #expect(updated?.constraint == .width)
        #expect(updated?.value == 250)
        #expect(viewModel.exportSettings.scale == 2.5)
        #expect(viewModel.document.history.count == historyAfterConstraint + 1)

        viewModel.undo()
        #expect(viewModel.document.slices[0].exportPresets?[0].value == 200)
        #expect(viewModel.exportSettings.scale == 2)
        viewModel.redo()
        #expect(viewModel.document.slices[0].exportPresets?[0] == updated)
        #expect(viewModel.exportSettings.scale == 2.5)

        #expect(viewModel.changeSliceExportPresetConstraint(
            inSlice: slice.id,
            at: 0,
            to: .height
        ))
        #expect(viewModel.document.slices[0].exportPresets?[0].constraint == .height)
        #expect(viewModel.document.slices[0].exportPresets?[0].value == 125)
        #expect(viewModel.exportSettings.scale == 2.5)

        let historyAfterEdits = viewModel.document.history.count
        #expect(!viewModel.changeSliceExportPresetConstraint(
            inSlice: slice.id,
            at: 2,
            to: .height
        ))
        #expect(viewModel.document.slices[0].exportPresets?[2] == presets[2])
        #expect(viewModel.statusText == L10n.text("imageEditor.status.sliceExportPresetUnchanged"))
        #expect(!viewModel.updateSliceExportPresetValue(
            inSlice: slice.id,
            at: 2,
            value: 2
        ))
        #expect(viewModel.document.slices[0].exportPresets?[2] == presets[2])
        #expect(viewModel.document.history.count == historyAfterEdits)
        #expect(!viewModel.changeSliceExportPresetConstraint(
            inSlice: slice.id,
            at: 99,
            to: .scale
        ))
        #expect(viewModel.document.history.count == historyAfterEdits)
    }

    @Test func exportingAllSlicesUsesPresetsFallbackScalesAndCollisionSafeNames() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "delivery.png",
            image: NSImage.rendered(size: CGSize(width: 40, height: 20)) { rect in
                NSColor.systemBlue.setFill()
                rect.fill()
            }!
        ) { _ in }
        let presetSlice = ImageEditorSlice(
            name: "Hero",
            frame: CGRect(x: 0, y: 0, width: 10, height: 10),
            exportPresets: [
                ImageEditorSliceExportPreset(
                    suffix: "@2x",
                    format: .png,
                    constraint: .scale,
                    value: 2
                ),
                ImageEditorSliceExportPreset(
                    suffix: "-wide",
                    format: .jpeg,
                    constraint: .width,
                    value: 30
                )
            ]
        )
        let fallbackSlice = ImageEditorSlice(
            name: "Hero",
            frame: CGRect(x: 12, y: 2, width: 8, height: 6)
        )
        viewModel.document.slices = [presetSlice, fallbackSlice]
        let settings = ImageEditorExportSettings(
            format: .png,
            scope: .slice,
            scale: 1,
            batchScales: [2],
            filenameSuffix: "-selected-only"
        )

        let plan = viewModel.sliceExportPlan(settings: settings)

        #expect(plan.map(\.sliceID) == [
            presetSlice.id,
            presetSlice.id,
            fallbackSlice.id,
            fallbackSlice.id
        ])
        #expect(plan.map(\.filename) == [
            "Hero@2x.png",
            "Hero-wide.jpg",
            "Hero@1x.png",
            "Hero@2x-2.png"
        ])
        #expect(plan.map(\.settings.format) == [.png, .jpeg, .png, .png])
        #expect(plan.map(\.settings.scale) == [2, 3, 1, 2])
        #expect(plan.map(\.settings.filenameSuffix) == ["@2x", "-wide", "", ""])
        #expect(plan.allSatisfy { variant in
            variant.settings.scope == .slice
                && variant.settings.sliceID == variant.sliceID
                && variant.settings.batchScales.isEmpty
        })

        let artifacts = try #require(viewModel.sliceExportArtifacts(settings: settings))
        #expect(artifacts.map(\.variant.filename) == plan.map(\.filename))
        var sizes: [CGSize] = []
        for artifact in artifacts {
            let image = try #require(NSImage(data: artifact.data))
            sizes.append(image.size)
        }
        #expect(sizes == [
            CGSize(width: 20, height: 20),
            CGSize(width: 30, height: 30),
            CGSize(width: 8, height: 6),
            CGSize(width: 16, height: 12)
        ])

        let conflicts = ImageEditorSliceExportConflictPolicy.conflictingFilenames(
            in: plan
        ) { filename in
            filename == "Hero-wide.jpg" || filename == "Hero@2x-2.png"
        }
        #expect(conflicts == ["Hero-wide.jpg", "Hero@2x-2.png"])

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "xomo-tests.slice-export.\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        viewModel.isExportSheetPresented = true
        let exportedCount = viewModel.exportAllSlices(settings: settings, to: directory)
        #expect(exportedCount == 4)
        #expect(!viewModel.isExportSheetPresented)
        let exportedNames = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(Set(exportedNames) == Set(plan.map(\.filename)))
        let protectedURL = directory.appendingPathComponent("Hero@2x.png")
        let protectedData = try Data(contentsOf: protectedURL)

        let repeatedCount = viewModel.exportAllSlices(settings: settings, to: directory)
        #expect(repeatedCount == 0)
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.exportSliceConflicts",
            4
        ))
        let protectedDataAfterConflict = try Data(contentsOf: protectedURL)
        #expect(protectedDataAfterConflict == protectedData)
    }

    @Test func exportingAllSlicesCanSkipExistingFilesWithoutOverwritingThem() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "delivery.png",
            image: NSImage.rendered(size: CGSize(width: 40, height: 20)) { rect in
                NSColor.systemTeal.setFill()
                rect.fill()
            }!
        ) { _ in }
        viewModel.document.slices = [
            ImageEditorSlice(
                name: "Alpha",
                frame: CGRect(x: 0, y: 0, width: 10, height: 10)
            ),
            ImageEditorSlice(
                name: "Beta",
                frame: CGRect(x: 12, y: 0, width: 10, height: 10)
            )
        ]
        var settings = ImageEditorExportSettings()
        settings.scope = .slice
        settings.format = .png
        settings.scale = 1
        let plan = viewModel.sliceExportPlan(settings: settings)
        #expect(plan.count == 2)
        let firstFilename = plan[0].filename
        let secondFilename = plan[1].filename
        let resolution = ImageEditorSliceExportConflictPolicy.resolve(
            plan: plan,
            policy: .skipExisting
        ) { $0 == firstFilename }
        #expect(resolution.conflictingFilenames == [firstFilename])
        #expect(resolution.deliverablePlan.map(\.filename) == [secondFilename])

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "xomo-tests.slice-export-skip.\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let protectedURL = directory.appendingPathComponent(firstFilename)
        let protectedData = Data("keep-existing".utf8)
        try protectedData.write(to: protectedURL, options: .atomic)

        let abortedCount = viewModel.exportAllSlices(settings: settings, to: directory)
        #expect(abortedCount == 0)
        #expect(!FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(secondFilename).path
        ))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.exportSliceConflicts", 1))

        settings.sliceConflictPolicy = .skipExisting
        viewModel.isExportSheetPresented = true
        let exportedCount = viewModel.exportAllSlices(settings: settings, to: directory)
        #expect(exportedCount == 1)
        #expect(try Data(contentsOf: protectedURL) == protectedData)
        #expect(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(secondFilename).path
        ))
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.exportedSlicesSkippingExisting",
            1,
            1,
            directory.lastPathComponent
        ))
        #expect(!viewModel.isExportSheetPresented)

        let repeatedCount = viewModel.exportAllSlices(settings: settings, to: directory)
        #expect(repeatedCount == 0)
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.exportSlicesAllSkipped",
            2
        ))
        #expect(try Data(contentsOf: protectedURL) == protectedData)
    }

    @Test func hotspotHTMLExportEmbedsCanvasAndEscapesImageMapMetadata() throws {
        let image = NSImage.transparent(size: CGSize(width: 80, height: 60))
        let pngData = try #require(image.qingtuPNGData())
        let hotspot = ImageEditorHotspot(
            name: "Hero & Link",
            frame: CGRect(x: 10, y: 12, width: 30, height: 20),
            url: "https://example.com/a?x=1&y=2"
        )

        let data = ImageEditorHotspotHTMLExporter.data(
            canvasSize: image.size,
            pngData: pngData,
            hotspots: [hotspot],
            title: "Demo <Page>"
        )
        let html = try #require(String(data: data, encoding: .utf8))

        #expect(html.contains("usemap=\"#xomo-hotspots\""))
        #expect(html.contains("data:image/png;base64,"))
        #expect(html.contains("coords=\"10,12,40,32\""))
        #expect(html.contains("Hero &amp; Link"))
        #expect(html.contains("https://example.com/a?x=1&amp;y=2"))
        #expect(html.contains("<title>Demo &lt;Page&gt;</title>"))
    }

    @Test func selectedLayerExportScopeChoosesSingleLayerOrLayerSubtree() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "layers",
            image: NSImage.transparent(size: CGSize(width: 120, height: 80))
        ) { _ in }
        let baseLayerID = try #require(viewModel.document.selectedLayerID)

        #expect(viewModel.selectedLayersExportScope == .selectedLayer)

        viewModel.addLayer()
        let secondLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.selectLayer(baseLayerID, extendingSelection: true)

        #expect(viewModel.document.selectedLayerIDs == [baseLayerID, secondLayerID])
        #expect(viewModel.selectedLayersExportScope == .selectedLayers)
    }
}
