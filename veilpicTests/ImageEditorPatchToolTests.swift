//
//  ImageEditorPatchToolTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/13.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorPatchToolTests {
    @Test func fractionalPointerMovementSnapsPatchTransferToWholeCanvasPixels() {
        let start = CGPoint(x: 10.25, y: 20.75)
        let free = ImageEditorPatchDragConstraint.resolve(
            start: start,
            proposedEnd: CGPoint(x: 17.7, y: 16.2),
            existingAxis: nil,
            isConstrained: false
        )
        #expect(free.axis == nil)
        #expect(free.endPoint == CGPoint(x: 17.25, y: 15.75))
        #expect(free.endPoint.x - start.x == 7)
        #expect(free.endPoint.y - start.y == -5)

        let vertical = ImageEditorPatchDragConstraint.resolve(
            start: start,
            proposedEnd: CGPoint(x: 15.15, y: 30.15),
            existingAxis: nil,
            isConstrained: true
        )
        #expect(vertical.axis == .vertical)
        #expect(vertical.endPoint == CGPoint(x: 10.25, y: 29.75))

        #expect(ImageEditorPatchPixelGrid.snappedDelta(
            CGSize(width: -0.49, height: 0.49)
        ) == .zero)
    }

    @Test func pixelSnappedEndpointIsSharedByPreviewHUDGuidesAndCommit() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let updateStart = try #require(source.range(of: "private func updatePatchDrag("))
        let updateTail = source[updateStart.lowerBound...]
        let updateEnd = try #require(updateTail.range(of: "@discardableResult\n    private func beginPendingCropInteraction"))
        let updateSource = updateTail[..<updateEnd.lowerBound]

        #expect(updateSource.contains("ImageEditorPatchDragConstraint.resolve("))
        #expect(updateSource.contains("dragEnd = constrainedEnd.endPoint"))
        #expect(updateSource.contains("viewModel.updatePointer(constrainedEnd.endPoint)"))
        #expect(updateSource.contains("to: constrainedEnd.endPoint"))
        #expect(source.components(separatedBy: "dragEnd.x - dragStart.x").count == 4)
        #expect(source.components(separatedBy: "dragEnd.y - dragStart.y").count == 4)

        let commitStart = try #require(
            source.range(of: "case .patchTool:\n                    if isDrawingPatchSelection")
        )
        let commitTail = source[commitStart.lowerBound...]
        let commitEnd = try #require(commitTail.range(of: "case .redEye:"))
        let commitSource = commitTail[..<commitEnd.lowerBound]
        #expect(commitSource.contains("ImageEditorPatchDragConstraint.resolve("))
        #expect(commitSource.contains("to: constrainedEnd.endPoint"))
    }

    @Test func escapeCancellationOnlyOwnsAnActivePatchPointerSequence() {
        #expect(ImageEditorPatchGestureCancellationPolicy.shouldCancel(
            tool: .patchTool,
            hasDragStart: true,
            hasDrawnPoints: false,
            isDrawingSelection: false,
            hasPreview: true
        ))
        #expect(ImageEditorPatchGestureCancellationPolicy.shouldCancel(
            tool: .patchTool,
            hasDragStart: false,
            hasDrawnPoints: true,
            isDrawingSelection: true,
            hasPreview: false
        ))
        #expect(!ImageEditorPatchGestureCancellationPolicy.shouldCancel(
            tool: .patchTool,
            hasDragStart: false,
            hasDrawnPoints: false,
            isDrawingSelection: false,
            hasPreview: false
        ))
        #expect(!ImageEditorPatchGestureCancellationPolicy.shouldCancel(
            tool: .move,
            hasDragStart: true,
            hasDrawnPoints: true,
            isDrawingSelection: true,
            hasPreview: true
        ))
    }

    @Test func escapeCancellationWiresTransientResetAndMouseUpLatch() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let functionStart = try #require(
            source.range(of: "private func cancelPatchGestureForCanvasLifecycle() -> Bool")
        )
        let functionTail = source[functionStart.lowerBound...]
        let functionEnd = try #require(functionTail.range(of: "private func updatePatchDrag("))
        let functionSource = functionTail[..<functionEnd.lowerBound]

        #expect(source.contains("if cancelPatchGestureForCanvasLifecycle() {"))
        #expect(functionSource.contains("ImageEditorPatchGestureCancellationPolicy.shouldCancel("))
        #expect(functionSource.contains("dragStart = nil"))
        #expect(functionSource.contains("dragEnd = nil"))
        #expect(functionSource.contains("dragPoints = []"))
        #expect(functionSource.contains("patchPreviewImage = nil"))
        #expect(functionSource.contains("patchRawDragEnd = nil"))
        #expect(functionSource.contains("patchDragConstraintAxis = nil"))
        #expect(functionSource.contains("isDrawingPatchSelection = false"))
        #expect(functionSource.contains("isPatchGestureBlocked = true"))
        #expect(functionSource.contains("lastPatchPreviewUpdateTime = 0"))
        #expect(source.contains("if dragStart == nil, dragPoints.isEmpty, !isPatchGestureBlocked"))
        #expect(source.contains("isPatchGestureBlocked = false"))
    }

    @Test func transferHUDShowsFreeDistanceAndShiftConstraintDirection() {
        let frame = CGRect(x: 10, y: 12, width: 20, height: 14)
        #expect(
            ImageEditorTransformHUD.displayText(
                frame: frame,
                mode: .patchTransfer(
                    delta: CGSize(width: 30, height: 40),
                    constrainedAxis: nil
                )
            ) == "ΔX 30  ΔY 40  ·  D 50"
        )
        #expect(
            ImageEditorTransformHUD.displayText(
                frame: frame,
                mode: .patchTransfer(
                    delta: CGSize(width: -18.5, height: 0),
                    constrainedAxis: .horizontal
                )
            ) == "⇧↔  ΔX -18.5  ΔY 0"
        )
        #expect(
            ImageEditorTransformHUD.displayText(
                frame: frame,
                mode: .patchTransfer(
                    delta: CGSize(width: 0, height: 27.25),
                    constrainedAxis: .vertical
                )
            ) == "⇧↕  ΔX 0  ΔY 27.3"
        )
    }

    @Test func shiftConstrainedDragLocksPreviewAndCommitToTheDominantAxis() {
        let start = CGPoint(x: 20, y: 30)
        let horizontal = ImageEditorPatchDragConstraint.resolve(
            start: start,
            proposedEnd: CGPoint(x: 56, y: 42),
            existingAxis: nil,
            isConstrained: true
        )
        #expect(horizontal.axis == .horizontal)
        #expect(horizontal.endPoint == CGPoint(x: 56, y: 30))

        let latchedHorizontal = ImageEditorPatchDragConstraint.resolve(
            start: start,
            proposedEnd: CGPoint(x: 25, y: 70),
            existingAxis: horizontal.axis,
            isConstrained: true
        )
        #expect(latchedHorizontal.axis == .horizontal)
        #expect(latchedHorizontal.endPoint == CGPoint(x: 25, y: 30))

        let vertical = ImageEditorPatchDragConstraint.resolve(
            start: start,
            proposedEnd: CGPoint(x: 27, y: 68),
            existingAxis: nil,
            isConstrained: true
        )
        #expect(vertical.axis == .vertical)
        #expect(vertical.endPoint == CGPoint(x: 20, y: 68))

        let released = ImageEditorPatchDragConstraint.resolve(
            start: start,
            proposedEnd: CGPoint(x: 27, y: 68),
            existingAxis: vertical.axis,
            isConstrained: false
        )
        #expect(released.axis == nil)
        #expect(released.endPoint == CGPoint(x: 27, y: 68))
    }

    @Test func transferGuideSwapsSourceAndTargetWithoutChangingSelectionGeometry() throws {
        let selection = ImageEditorSelection.rectangle(
            CGRect(x: 10, y: 12, width: 20, height: 14)
        )
        let selectionEdges = ImageEditorSelectionEdgeGeometry.make(
            selection: selection,
            canvasSize: CGSize(width: 100, height: 80)
        )
        let dragStart = CGPoint(x: 18, y: 18)
        let dragEnd = CGPoint(x: 48, y: 38)

        let sourceGuide = try #require(ImageEditorPatchTransferGuide.make(
            selectionEdges: selectionEdges,
            selectionBounds: selection.bounds,
            dragStart: dragStart,
            dragEnd: dragEnd,
            mode: .source
        ))
        let destinationGuide = try #require(ImageEditorPatchTransferGuide.make(
            selectionEdges: selectionEdges,
            selectionBounds: selection.bounds,
            dragStart: dragStart,
            dragEnd: dragEnd,
            mode: .destination
        ))

        #expect(sourceGuide.targetEdges == selectionEdges)
        #expect(destinationGuide.sourceEdges == selectionEdges)
        #expect(sourceGuide.sourceEdges == destinationGuide.targetEdges)
        #expect(sourceGuide.sourceAnchor == CGPoint(x: 50, y: 39))
        #expect(sourceGuide.targetAnchor == CGPoint(x: 20, y: 19))
        #expect(destinationGuide.sourceAnchor == sourceGuide.targetAnchor)
        #expect(destinationGuide.targetAnchor == sourceGuide.sourceAnchor)
        #expect(ImageEditorPatchTransferGuide.make(
            selectionEdges: selectionEdges,
            selectionBounds: selection.bounds,
            dragStart: dragStart,
            dragEnd: CGPoint(x: CGFloat.infinity, y: 38),
            mode: .source
        ) == nil)
    }

    @Test func sourceModePreviewIsNonDestructiveAndCommitSupportsUndo() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.patchMode = .source
        viewModel.createRectSelection(from: fixture.blemishRect.origin, to: fixture.blemishRect.bottomRight)
        let sampleBefore = try color(in: viewModel, at: fixture.sampleRect.center)
        let blemishBefore = try color(in: viewModel, at: fixture.blemishRect.center)
        #expect(sampleBefore.greenComponent > 0.75)
        #expect(blemishBefore.greenComponent < 0.1)
        let beforePixels = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let beforeHistoryCount = viewModel.document.history.count
        let selectionBefore = viewModel.document.selection

        let preview = try #require(viewModel.patchPreviewImage(
            from: fixture.blemishRect.center,
            to: fixture.sampleRect.center
        ))

        #expect(preview.qingtuPNGData() != viewModel.currentImage.qingtuPNGData())
        #expect(viewModel.document.selectedLayer?.image.qingtuPNGData() == beforePixels)
        #expect(viewModel.document.history.count == beforeHistoryCount)
        #expect(viewModel.document.selection == selectionBefore)

        viewModel.patchSelection(from: fixture.blemishRect.center, to: fixture.sampleRect.center)
        let patched = try color(in: viewModel, at: fixture.blemishRect.center)
        #expect(patched.greenComponent > 0.75)
        #expect(patched.redComponent < 0.35)
        #expect(viewModel.document.selection == selectionBefore)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionPatch"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionPatchedSource"))

        viewModel.undo()
        let restored = try color(in: viewModel, at: fixture.blemishRect.center)
        #expect(restored.greenComponent < 0.1)
    }

    @Test func destinationModeCopiesOriginalSelectionToDraggedTargetAndMovesSelection() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.patchMode = .destination
        viewModel.createRectSelection(from: fixture.sampleRect.origin, to: fixture.sampleRect.bottomRight)
        let sourceBefore = try color(in: viewModel, at: fixture.sampleRect.center)
        let destinationBefore = try color(in: viewModel, at: fixture.blemishRect.center)
        #expect(sourceBefore.greenComponent > 0.75)
        #expect(destinationBefore.greenComponent < 0.1)
        let selectionBefore = try #require(viewModel.document.selection)

        viewModel.patchSelection(from: fixture.sampleRect.center, to: fixture.blemishRect.center)

        let destination = try color(in: viewModel, at: fixture.blemishRect.center)
        let source = try color(in: viewModel, at: fixture.sampleRect.center)
        #expect(destination.greenComponent > 0.75)
        #expect(destination.redComponent < 0.35)
        #expect(source.greenComponent > 0.75)
        #expect(viewModel.document.selection?.bounds == selectionBefore.bounds.offsetBy(dx: 20, dy: 0))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionPatchedDestination"))

        viewModel.undo()
        let restored = try color(in: viewModel, at: fixture.blemishRect.center)
        #expect(restored.greenComponent < 0.1)
        #expect(viewModel.document.selection == selectionBefore)
    }

    @Test func transparentModeTransfersTextureWithoutReplacingTargetColorOrAlpha() throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let sampleRect = CGRect(x: 12, y: 22, width: 16, height: 16)
        let targetRect = CGRect(x: 32, y: 22, width: 16, height: 16)
        let textureMark = CGRect(x: 18, y: 28, width: 4, height: 4)
        let targetColor = NSColor(deviceRed: 0.2, green: 0.4, blue: 0.6, alpha: 0.7)
        let image = bitmapImage(
            size: canvasSize,
            background: targetColor,
            fills: [
                (sampleRect, NSColor(deviceWhite: 0.5, alpha: 1)),
                (textureMark, NSColor(deviceWhite: 1, alpha: 1))
            ]
        )

        func patchedCenter(transparent: Bool) throws -> NSColor {
            let viewModel = ImageEditorViewModel(
                sourceName: "transparent-texture-patch.png",
                image: image
            ) { _ in }
            viewModel.replaceSelectedLayerImageForTesting(
                image,
                historyTitle: L10n.text("imageEditor.history.brush")
            )
            viewModel.patchTransparentEnabled = transparent
            viewModel.createRectSelection(from: targetRect.origin, to: targetRect.bottomRight)
            viewModel.patchSelection(from: targetRect.center, to: sampleRect.center)
            return try color(in: viewModel, at: targetRect.center)
        }

        let opaqueReplacement = try patchedCenter(transparent: false)
        #expect(abs(opaqueReplacement.redComponent - opaqueReplacement.greenComponent) < 0.03)
        #expect(abs(opaqueReplacement.greenComponent - opaqueReplacement.blueComponent) < 0.03)
        #expect(opaqueReplacement.alphaComponent > 0.95)

        let transparentTexture = try patchedCenter(transparent: true)
        #expect(transparentTexture.redComponent < transparentTexture.greenComponent)
        #expect(transparentTexture.greenComponent < transparentTexture.blueComponent)
        #expect(transparentTexture.redComponent > targetColor.redComponent)
        #expect(abs(transparentTexture.alphaComponent - targetColor.alphaComponent) < 0.03)
    }

    @Test func transparentOptionIsWiredToTheOptionsBarAndLivePreview() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("isOn: $viewModel.patchTransparentEnabled"))
        #expect(source.contains(".accessibilityIdentifier(\"image-editor-patch-transparent\")"))
        #expect(source.contains(".onChange(of: viewModel.patchTransparentEnabled)"))
        #expect(source.contains("refreshActivePatchPreview()"))
    }

    @Test func patchLassoHonorsReplaceAddSubtractAndIntersectSelectionModes() throws {
        #expect(ImageEditorTool.patchTool.supportsSelectionMode)
        let points = [
            CGPoint(x: 20, y: 10),
            CGPoint(x: 40, y: 10),
            CGPoint(x: 40, y: 30),
            CGPoint(x: 20, y: 30)
        ]
        let canvasSize = CGSize(width: 80, height: 60)

        func resolvedSelection(for mode: ImageEditorSelectionMode) throws -> ImageEditorSelection {
            let viewModel = makeFixture().viewModel
            viewModel.selectionMode = .replace
            viewModel.createRectSelection(
                from: CGPoint(x: 10, y: 10),
                to: CGPoint(x: 30, y: 30)
            )
            viewModel.selectionMode = mode
            viewModel.createPatchSelection(points: points)
            #expect(viewModel.selectionMode == mode)
            #expect(viewModel.statusText == L10n.text("imageEditor.status.patchSelectionReady"))
            return try #require(viewModel.document.selection)
        }

        let replace = try resolvedSelection(for: .replace)
        #expect(!replace.contains(CGPoint(x: 15, y: 20), canvasSize: canvasSize))
        #expect(replace.contains(CGPoint(x: 25, y: 20), canvasSize: canvasSize))
        #expect(replace.contains(CGPoint(x: 35, y: 20), canvasSize: canvasSize))

        let add = try resolvedSelection(for: .add)
        #expect(add.contains(CGPoint(x: 15, y: 20), canvasSize: canvasSize))
        #expect(add.contains(CGPoint(x: 25, y: 20), canvasSize: canvasSize))
        #expect(add.contains(CGPoint(x: 35, y: 20), canvasSize: canvasSize))

        let subtract = try resolvedSelection(for: .subtract)
        #expect(subtract.contains(CGPoint(x: 15, y: 20), canvasSize: canvasSize))
        #expect(!subtract.contains(CGPoint(x: 25, y: 20), canvasSize: canvasSize))
        #expect(!subtract.contains(CGPoint(x: 35, y: 20), canvasSize: canvasSize))

        let intersect = try resolvedSelection(for: .intersect)
        #expect(!intersect.contains(CGPoint(x: 15, y: 20), canvasSize: canvasSize))
        #expect(intersect.contains(CGPoint(x: 25, y: 20), canvasSize: canvasSize))
        #expect(!intersect.contains(CGPoint(x: 35, y: 20), canvasSize: canvasSize))

        let emptiedViewModel = makeFixture().viewModel
        emptiedViewModel.selectionMode = .replace
        emptiedViewModel.createPatchSelection(points: points)
        emptiedViewModel.selectionMode = .subtract
        emptiedViewModel.createPatchSelection(points: points)
        #expect(emptiedViewModel.document.selection == nil)
        #expect(emptiedViewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func patchHoverHitTestingHandlesGeometryRasterMasksAndInversionWithoutRendering() throws {
        let canvasSize = CGSize(width: 40, height: 40)
        var rectangle = ImageEditorSelection.rectangle(
            CGRect(x: 10, y: 10, width: 10, height: 10)
        )
        #expect(rectangle.contains(CGPoint(x: 15, y: 15), canvasSize: canvasSize))
        #expect(!rectangle.contains(CGPoint(x: 5, y: 5), canvasSize: canvasSize))
        rectangle.isInverted = true
        #expect(!rectangle.contains(CGPoint(x: 15, y: 15), canvasSize: canvasSize))
        #expect(rectangle.contains(CGPoint(x: 5, y: 5), canvasSize: canvasSize))
        #expect(!rectangle.contains(CGPoint(x: 41, y: 5), canvasSize: canvasSize))

        var alpha = [UInt8](repeating: 0, count: 16)
        alpha[2 * 4 + 1] = .max
        var raster = ImageEditorSelection.raster(
            mask: ImageEditorSelectionMask(width: 4, height: 4, alpha: alpha),
            bounds: CGRect(x: 10, y: 20, width: 10, height: 10)
        )
        #expect(raster.contains(CGPoint(x: 15, y: 25), canvasSize: canvasSize))
        #expect(!raster.contains(CGPoint(x: 25, y: 25), canvasSize: canvasSize))
        raster.isInverted = true
        #expect(!raster.contains(CGPoint(x: 15, y: 25), canvasSize: canvasSize))
        #expect(raster.contains(CGPoint(x: 25, y: 25), canvasSize: canvasSize))
    }

    @Test func patchCommitHonorsTransparentPixelLock() throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let sampleRect = CGRect(x: 12, y: 22, width: 16, height: 16)
        let blemishRect = CGRect(x: 32, y: 22, width: 16, height: 16)
        let image = bitmapImage(
            size: canvasSize,
            background: NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0),
            fills: [(sampleRect, NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1))]
        )
        let viewModel = ImageEditorViewModel(sourceName: "transparent-patch.png", image: image) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            image,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.createRectSelection(from: blemishRect.origin, to: blemishRect.bottomRight)
        if let index = viewModel.document.selectedLayerIndex {
            viewModel.document.layers[index].locksTransparentPixels = true
        }

        viewModel.patchSelection(from: blemishRect.center, to: sampleRect.center)

        let lockedCenter = try color(in: viewModel, at: blemishRect.center)
        #expect(lockedCenter.alphaComponent < 0.1)
    }

    private struct Fixture {
        let viewModel: ImageEditorViewModel
        let sampleRect: CGRect
        let blemishRect: CGRect
    }

    private func makeFixture() -> Fixture {
        let canvasSize = NSSize(width: 80, height: 60)
        let sampleRect = CGRect(x: 12, y: 22, width: 16, height: 16)
        let blemishRect = CGRect(x: 32, y: 22, width: 16, height: 16)
        let image = bitmapImage(
            size: canvasSize,
            background: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1),
            fills: [
                (blemishRect, NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "patch.png", image: image) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            image,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        return Fixture(
            viewModel: viewModel,
            sampleRect: sampleRect,
            blemishRect: blemishRect
        )
    }

    private func color(in viewModel: ImageEditorViewModel, at point: CGPoint) throws -> NSColor {
        try #require(
            viewModel.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )
    }

    private func bitmapImage(
        size: NSSize,
        background: NSColor,
        fills: [(CGRect, NSColor)]
    ) -> NSImage {
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                let color = fills.last(where: { $0.0.contains(point) })?.1 ?? background
                guard let rgb = color.usingColorSpace(.deviceRGB) else { continue }
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = rgb.alphaComponent
                pixels[offset] = UInt8((rgb.redComponent * alpha * 255).rounded())
                pixels[offset + 1] = UInt8((rgb.greenComponent * alpha * 255).rounded())
                pixels[offset + 2] = UInt8((rgb.blueComponent * alpha * 255).rounded())
                pixels[offset + 3] = UInt8((alpha * 255).rounded())
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: [.byteOrder32Big, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)],
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else { return NSImage(size: size) }
        return NSImage(cgImage: image, size: size)
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
    var bottomRight: CGPoint { CGPoint(x: maxX, y: maxY) }
}
