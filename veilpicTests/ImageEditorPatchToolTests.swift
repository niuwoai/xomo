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

    @Test func diffusionSmoothsSampledDetailInNormalAndTransparentModes() throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let sampleRect = CGRect(x: 12, y: 22, width: 16, height: 16)
        let targetRect = CGRect(x: 32, y: 22, width: 16, height: 16)
        let textureMark = CGRect(x: 19, y: 29, width: 2, height: 2)
        let targetColor = NSColor(deviceRed: 0.15, green: 0.25, blue: 0.35, alpha: 1)
        let image = bitmapImage(
            size: canvasSize,
            background: targetColor,
            fills: [
                (sampleRect, NSColor(deviceWhite: 0.45, alpha: 1)),
                (textureMark, NSColor(deviceWhite: 1, alpha: 1))
            ]
        )

        func patchedCenter(diffusion: Int, transparent: Bool) throws -> NSColor {
            let viewModel = ImageEditorViewModel(
                sourceName: "diffused-patch.png",
                image: image
            ) { _ in }
            #expect(viewModel.patchDiffusion == 1)
            viewModel.replaceSelectedLayerImageForTesting(
                image,
                historyTitle: L10n.text("imageEditor.history.brush")
            )
            viewModel.patchDiffusion = diffusion
            viewModel.patchTransparentEnabled = transparent
            viewModel.createRectSelection(from: targetRect.origin, to: targetRect.bottomRight)
            viewModel.patchSelection(from: targetRect.center, to: sampleRect.center)
            return try color(in: viewModel, at: targetRect.center)
        }

        let sharpNormal = try patchedCenter(diffusion: 1, transparent: false)
        let smoothNormal = try patchedCenter(diffusion: 7, transparent: false)
        #expect(sharpNormal.redComponent > smoothNormal.redComponent + 0.15)

        let sharpTransparent = try patchedCenter(diffusion: 1, transparent: true)
        let smoothTransparent = try patchedCenter(diffusion: 7, transparent: true)
        let sharpTextureDelta = sharpTransparent.redComponent - targetColor.redComponent
        let smoothTextureDelta = smoothTransparent.redComponent - targetColor.redComponent
        #expect(sharpTextureDelta > smoothTextureDelta + 0.08)
        #expect(abs(smoothTransparent.alphaComponent - targetColor.alphaComponent) < 0.01)
    }

    @Test func sampleAllLayersUsesVisibleCompositeButWritesOnlyTheActiveLayer() throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let sampleRect = CGRect(x: 12, y: 22, width: 16, height: 16)
        let targetRect = CGRect(x: 42, y: 22, width: 16, height: 16)
        let bottomImage = bitmapImage(
            size: canvasSize,
            background: NSColor(deviceRed: 0.05, green: 0.15, blue: 0.65, alpha: 1),
            fills: [(sampleRect, NSColor(deviceRed: 0.9, green: 0.1, blue: 0.05, alpha: 1))]
        )
        var document = ImageEditorDocument(sourceName: "patch-all-layers.png", image: bottomImage)
        let editLayer = ImageEditorLayer.blank(name: "Patch Target", size: canvasSize)
        let hiddenYellow = bitmapImage(
            size: canvasSize,
            background: NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0),
            fills: [(sampleRect, NSColor(deviceRed: 1, green: 1, blue: 0, alpha: 1))]
        )
        var hiddenLayer = ImageEditorLayer.blank(name: "Hidden", size: canvasSize)
        hiddenLayer.image = hiddenYellow
        hiddenLayer.isVisible = false
        document.layers = [document.layers[0], editLayer, hiddenLayer]
        document.selectedLayerID = editLayer.id
        document.selectedLayerIDs = [editLayer.id]
        let viewModel = ImageEditorViewModel(document: document, onApply: { _ in })
        #expect(!viewModel.patchSampleAllLayersEnabled)
        viewModel.patchSampleAllLayersEnabled = true
        viewModel.createRectSelection(from: targetRect.origin, to: targetRect.bottomRight)

        viewModel.patchSelection(from: targetRect.center, to: sampleRect.center)

        let patched = try color(in: viewModel, at: targetRect.center)
        #expect(patched.redComponent > patched.blueComponent + 0.6)
        #expect(patched.greenComponent < 0.25)
        let unchangedBottom = try #require(
            viewModel.document.layers[0].image.color(at: sampleRect.center)?.usingColorSpace(.deviceRGB)
        )
        #expect(unchangedBottom.redComponent > unchangedBottom.blueComponent + 0.6)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionPatch"))

        viewModel.undo()
        let undone = try color(in: viewModel, at: targetRect.center)
        #expect(undone.alphaComponent < 0.05)
        viewModel.redo()
        let redone = try color(in: viewModel, at: targetRect.center)
        #expect(redone.redComponent > redone.blueComponent + 0.6)
    }

    @Test func currentAndBelowSampleSourceExcludesVisibleLayersAboveThePatchTarget() throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let sampleRect = CGRect(x: 12, y: 22, width: 16, height: 16)
        let targetRect = CGRect(x: 42, y: 22, width: 16, height: 16)

        func patchedCenter(source: ImageEditorCloneSampleSource) throws -> NSColor {
            let bottomImage = bitmapImage(
                size: canvasSize,
                background: .clear,
                fills: [(sampleRect, NSColor(deviceRed: 0.9, green: 0.05, blue: 0.05, alpha: 1))]
            )
            var document = ImageEditorDocument(sourceName: "patch-source-range.png", image: bottomImage)
            let editLayer = ImageEditorLayer.blank(name: "Patch Target", size: canvasSize)
            let upperImage = bitmapImage(
                size: canvasSize,
                background: .clear,
                fills: [(sampleRect, NSColor(deviceRed: 0.05, green: 0.9, blue: 0.05, alpha: 1))]
            )
            var upperLayer = ImageEditorLayer.blank(name: "Upper Annotation", size: canvasSize)
            upperLayer.image = upperImage
            document.layers = [document.layers[0], editLayer, upperLayer]
            document.selectedLayerID = editLayer.id
            document.selectedLayerIDs = [editLayer.id]
            let viewModel = ImageEditorViewModel(document: document, onApply: { _ in })
            #expect(viewModel.patchSampleSource == .currentLayer)
            viewModel.patchSampleSource = source
            viewModel.createRectSelection(from: targetRect.origin, to: targetRect.bottomRight)
            viewModel.patchSelection(from: targetRect.center, to: sampleRect.center)
            return try color(in: viewModel, at: targetRect.center)
        }

        let currentAndBelow = try patchedCenter(source: .currentAndBelow)
        let allVisible = try patchedCenter(source: .allVisible)
        #expect(currentAndBelow.redComponent > currentAndBelow.greenComponent + 0.6)
        #expect(allVisible.greenComponent > allVisible.redComponent + 0.6)
    }

    @Test func ignoreAdjustmentsFiltersTheCompositePatchSample() throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let sampleRect = CGRect(x: 12, y: 22, width: 16, height: 16)
        let targetRect = CGRect(x: 42, y: 22, width: 16, height: 16)

        func patchedCenter(ignoresAdjustments: Bool) throws -> NSColor {
            let black = bitmapImage(size: canvasSize, background: .black, fills: [])
            var document = ImageEditorDocument(sourceName: "adjusted-patch.png", image: black)
            let adjustment = ImageEditorLayer.adjustment(
                name: "Invert",
                size: canvasSize,
                kind: .invert,
                amount: 1
            )
            let editLayer = ImageEditorLayer.blank(name: "Patch Target", size: canvasSize)
            document.layers = [document.layers[0], adjustment, editLayer]
            document.selectedLayerID = editLayer.id
            document.selectedLayerIDs = [editLayer.id]
            let viewModel = ImageEditorViewModel(document: document, onApply: { _ in })
            #expect(!viewModel.patchIgnoresAdjustmentLayers)
            viewModel.patchSampleAllLayersEnabled = true
            viewModel.patchIgnoresAdjustmentLayers = ignoresAdjustments
            viewModel.createRectSelection(from: targetRect.origin, to: targetRect.bottomRight)
            viewModel.patchSelection(from: targetRect.center, to: sampleRect.center)
            return try color(in: viewModel, at: targetRect.center)
        }

        let adjusted = try patchedCenter(ignoresAdjustments: false)
        let raw = try patchedCenter(ignoresAdjustments: true)
        #expect(adjusted.redComponent > 0.9)
        #expect(adjusted.greenComponent > 0.9)
        #expect(adjusted.blueComponent > 0.9)
        #expect(raw.redComponent < 0.1)
        #expect(raw.greenComponent < 0.1)
        #expect(raw.blueComponent < 0.1)
        #expect(raw.alphaComponent > 0.95)
    }

    @Test func usePatternAppliesOneUndoablePatchTransaction() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "patch-pattern.png",
            image: .transparent(size: CGSize(width: 12, height: 12))
        ) { _ in }
        viewModel.selectAll()
        viewModel.opacity = 1
        viewModel.patchPatternContent = ImageEditorPatternFillContent(
            kind: .checkerboard,
            red: 1,
            green: 0,
            blue: 0,
            opacity: 1,
            scale: 6
        )
        let original = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.applyPatchPattern())

        let appliedImage = try #require(viewModel.document.selectedLayer?.image)
        let applied = try #require(appliedImage.qingtuPNGData())
        let pixels = try #require(imageEditorRGBABytes(appliedImage, width: 12, height: 12))
        let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        #expect(alpha.contains(0))
        #expect(alpha.contains(where: { $0 > 240 }))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionPatchPattern"))

        viewModel.undo()
        #expect(try #require(viewModel.document.selectedLayer?.image.qingtuPNGData()) == original)
        viewModel.redo()
        #expect(try #require(viewModel.document.selectedLayer?.image.qingtuPNGData()) == applied)
    }

    @Test func usePatternHonorsTransparentPixelLockWithoutCreatingHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "locked-patch-pattern.png",
            image: .transparent(size: CGSize(width: 12, height: 12))
        ) { _ in }
        viewModel.selectAll()
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].locksTransparentPixels = true
        let original = try #require(viewModel.document.layers[layerIndex].image.qingtuPNGData())
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(!viewModel.applyPatchPattern())
        #expect(try #require(viewModel.document.layers[layerIndex].image.qingtuPNGData()) == original)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
    }

    @Test func usePatternCanPreservePartialAndFullyTransparentPixels() throws {
        func appliedAlpha(preservesTransparency: Bool) throws -> [UInt8] {
            let source = NSImage(size: CGSize(width: 2, height: 1), flipped: false) { rect in
                NSColor.clear.setFill()
                rect.fill()
                NSColor(deviceRed: 0.2, green: 0.4, blue: 0.8, alpha: 0.5).setFill()
                CGRect(x: 0, y: 0, width: 1, height: 1).fill()
                return true
            }
            let viewModel = ImageEditorViewModel(
                sourceName: "patch-pattern-preserve-alpha.png",
                image: source
            ) { _ in }
            viewModel.replaceSelectedLayerImageForTesting(
                source,
                historyTitle: L10n.text("imageEditor.history.brush")
            )
            viewModel.selectAll()
            viewModel.opacity = 1
            viewModel.patchPatternPreservesTransparency = preservesTransparency
            viewModel.patchPatternContent = ImageEditorPatternFillContent(
                kind: .checkerboard,
                red: 1,
                green: 0,
                blue: 0,
                opacity: 1,
                scale: 6
            )

            #expect(viewModel.applyPatchPattern())
            let image = try #require(viewModel.document.selectedLayer?.image)
            let pixels = try #require(imageEditorRGBABytes(image, width: 2, height: 1))
            return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        }

        let unprotected = try appliedAlpha(preservesTransparency: false)
        let protected = try appliedAlpha(preservesTransparency: true)

        #expect(unprotected[0] > 240)
        #expect(unprotected[1] > 240)
        #expect(abs(Int(protected[0]) - 128) <= 2)
        #expect(protected[1] == 0)
    }

    @Test func usePatternCanInvertPaintedAndTransparentCoverage() throws {
        func appliedAlpha(invertsCoverage: Bool) throws -> [UInt8] {
            let viewModel = ImageEditorViewModel(
                sourceName: "patch-pattern-invert-coverage.png",
                image: .transparent(size: CGSize(width: 12, height: 12))
            ) { _ in }
            viewModel.selectAll()
            viewModel.opacity = 1
            viewModel.patchPatternInvertsCoverage = invertsCoverage
            viewModel.patchPatternContent = ImageEditorPatternFillContent(
                kind: .checkerboard,
                red: 1,
                green: 0,
                blue: 0,
                opacity: 1,
                scale: 6
            )

            #expect(viewModel.applyPatchPattern())
            let image = try #require(viewModel.document.selectedLayer?.image)
            let pixels = try #require(imageEditorRGBABytes(image, width: 12, height: 12))
            return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        }

        let normal = try appliedAlpha(invertsCoverage: false)
        let inverted = try appliedAlpha(invertsCoverage: true)

        #expect(normal != inverted)
        #expect(normal.contains(0) && normal.contains(where: { $0 > 240 }))
        #expect(inverted.contains(0) && inverted.contains(where: { $0 > 240 }))
        #expect(zip(normal, inverted).allSatisfy { alpha in
            abs(Int(alpha.0) + Int(alpha.1) - 255) <= 2
        })
    }

    @Test func usePatternScaleChangesTheAppliedTileFrequency() throws {
        func appliedAlphaRow(scale: CGFloat) throws -> [UInt8] {
            let viewModel = ImageEditorViewModel(
                sourceName: "patch-pattern-scale.png",
                image: .transparent(size: CGSize(width: 24, height: 24))
            ) { _ in }
            viewModel.selectAll()
            viewModel.opacity = 1
            viewModel.patchPatternContent = ImageEditorPatternFillContent(
                kind: .checkerboard,
                red: 1,
                green: 0,
                blue: 0,
                opacity: 1,
                scale: scale
            )

            #expect(viewModel.applyPatchPattern())
            let image = try #require(viewModel.document.selectedLayer?.image)
            let pixels = try #require(imageEditorRGBABytes(image, width: 24, height: 24))
            return stride(from: 3, to: 24 * 4, by: 4).map { pixels[$0] }
        }

        func transitionCount(_ values: [UInt8]) -> Int {
            zip(values, values.dropFirst()).reduce(into: 0) { count, pair in
                if pair.0 != pair.1 { count += 1 }
            }
        }

        let sixPixelTiles = try appliedAlphaRow(scale: 6)
        let twelvePixelTiles = try appliedAlphaRow(scale: 12)

        #expect(sixPixelTiles != twelvePixelTiles)
        #expect(transitionCount(sixPixelTiles) > transitionCount(twelvePixelTiles))
    }

    @Test func usePatternAngleRotatesTheRenderedCoverage() throws {
        func appliedAlpha(angle: CGFloat) throws -> [UInt8] {
            let viewModel = ImageEditorViewModel(
                sourceName: "patch-pattern-angle.png",
                image: .transparent(size: CGSize(width: 24, height: 24))
            ) { _ in }
            viewModel.selectAll()
            viewModel.opacity = 1
            viewModel.patchPatternContent = ImageEditorPatternFillContent(
                kind: .diagonalStripes,
                red: 1,
                green: 0,
                blue: 0,
                opacity: 1,
                scale: 8,
                angle: angle
            )

            #expect(viewModel.applyPatchPattern())
            let image = try #require(viewModel.document.selectedLayer?.image)
            let pixels = try #require(imageEditorRGBABytes(image, width: 24, height: 24))
            return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        }

        let original = try appliedAlpha(angle: 0)
        let quarterTurn = try appliedAlpha(angle: 90)

        #expect(original != quarterTurn)
        #expect(original.contains(where: { $0 < 32 }) && original.contains(where: { $0 > 224 }))
        #expect(quarterTurn.contains(where: { $0 < 32 }) && quarterTurn.contains(where: { $0 > 224 }))
    }

    @Test func usePatternFlipsTransformTheRenderedCoverage() throws {
        func appliedAlpha(flipsHorizontally: Bool, flipsVertically: Bool) throws -> [UInt8] {
            let viewModel = ImageEditorViewModel(
                sourceName: "patch-pattern-flip.png",
                image: .transparent(size: CGSize(width: 24, height: 24))
            ) { _ in }
            viewModel.selectAll()
            viewModel.opacity = 1
            viewModel.patchPatternContent = ImageEditorPatternFillContent(
                kind: .diagonalStripes,
                red: 1,
                green: 0,
                blue: 0,
                opacity: 1,
                scale: 8,
                flipsHorizontally: flipsHorizontally,
                flipsVertically: flipsVertically
            )

            #expect(viewModel.applyPatchPattern())
            let image = try #require(viewModel.document.selectedLayer?.image)
            let pixels = try #require(imageEditorRGBABytes(image, width: 24, height: 24))
            return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        }

        let original = try appliedAlpha(flipsHorizontally: false, flipsVertically: false)
        let horizontal = try appliedAlpha(flipsHorizontally: true, flipsVertically: false)
        let vertical = try appliedAlpha(flipsHorizontally: false, flipsVertically: true)

        #expect(horizontal != original)
        #expect(vertical != original)
        #expect(horizontal.contains(where: { $0 < 32 }) && horizontal.contains(where: { $0 > 224 }))
        #expect(vertical.contains(where: { $0 < 32 }) && vertical.contains(where: { $0 > 224 }))
    }

    @Test func usePatternAxisScalesTransformTheRenderedCoverage() throws {
        func appliedAlpha(scaleX: CGFloat, scaleY: CGFloat) throws -> [UInt8] {
            let viewModel = ImageEditorViewModel(
                sourceName: "patch-pattern-axis-scale.png",
                image: .transparent(size: CGSize(width: 24, height: 24))
            ) { _ in }
            viewModel.selectAll()
            viewModel.opacity = 1
            viewModel.patchPatternContent = ImageEditorPatternFillContent(
                kind: .diagonalStripes,
                red: 1,
                green: 0,
                blue: 0,
                opacity: 1,
                scale: 8,
                scaleX: scaleX,
                scaleY: scaleY
            )

            #expect(viewModel.applyPatchPattern())
            let image = try #require(viewModel.document.selectedLayer?.image)
            let pixels = try #require(imageEditorRGBABytes(image, width: 24, height: 24))
            return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        }

        let original = try appliedAlpha(scaleX: 1, scaleY: 1)
        let horizontal = try appliedAlpha(scaleX: 2, scaleY: 1)
        let vertical = try appliedAlpha(scaleX: 1, scaleY: 0.5)

        #expect(horizontal != original)
        #expect(vertical != original)
        #expect(horizontal.min() != horizontal.max())
        #expect(vertical.min() != vertical.max())
    }

    @Test func patternTransformPersistenceRoundTripsAndDefaultsOldProjects() throws {
        let content = ImageEditorPatternFillContent(
            kind: .diagonalStripes,
            scaleX: 1.75,
            scaleY: 0.6,
            angle: -37,
            flipsHorizontally: true,
            flipsVertically: true
        )
        let encoded = try JSONEncoder().encode(content)
        let decoded = try JSONDecoder().decode(ImageEditorPatternFillContent.self, from: encoded)

        #expect(decoded.flipsHorizontally)
        #expect(decoded.flipsVertically)
        #expect(decoded.scaleX == 1.75)
        #expect(decoded.scaleY == 0.6)

        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "scaleX")
        legacyObject.removeValue(forKey: "scaleY")
        legacyObject.removeValue(forKey: "flipsHorizontally")
        legacyObject.removeValue(forKey: "flipsVertically")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacy = try JSONDecoder().decode(ImageEditorPatternFillContent.self, from: legacyData)

        #expect(!legacy.flipsHorizontally)
        #expect(!legacy.flipsVertically)
        #expect(legacy.scaleX == 1)
        #expect(legacy.scaleY == 1)
        #expect(legacy.angle == -37)

        let normalized = ImageEditorPatternFillContent(scaleX: 0.1, scaleY: 5).normalized()
        #expect(normalized.scaleX == 0.25)
        #expect(normalized.scaleY == 4)
    }

    @Test func usePatternColorControlsTheRenderedPatternPixels() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "patch-pattern-color.png",
            image: .transparent(size: CGSize(width: 12, height: 12))
        ) { _ in }
        viewModel.selectAll()
        viewModel.opacity = 1
        viewModel.patchPatternContent = ImageEditorPatternFillContent(
            kind: .checkerboard,
            red: 0,
            green: 1,
            blue: 0,
            opacity: 1,
            scale: 6
        )

        #expect(viewModel.applyPatchPattern())
        let image = try #require(viewModel.document.selectedLayer?.image)
        let pixels = try #require(imageEditorRGBABytes(image, width: 12, height: 12))
        let opaqueOffset = try #require(stride(from: 0, to: pixels.count, by: 4).first {
            pixels[$0 + 3] > 240
        })

        #expect(pixels[opaqueOffset] < 15)
        #expect(pixels[opaqueOffset + 1] > 240)
        #expect(pixels[opaqueOffset + 2] < 15)
    }

    @Test func usePatternOpacityControlsTheRenderedPatternAlpha() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "patch-pattern-opacity.png",
            image: .transparent(size: CGSize(width: 12, height: 12))
        ) { _ in }
        viewModel.selectAll()
        viewModel.opacity = 1
        viewModel.patchPatternContent = ImageEditorPatternFillContent(
            kind: .checkerboard,
            red: 1,
            green: 0,
            blue: 0,
            opacity: 0.5,
            scale: 6
        )

        #expect(viewModel.applyPatchPattern())
        let image = try #require(viewModel.document.selectedLayer?.image)
        let pixels = try #require(imageEditorRGBABytes(image, width: 12, height: 12))
        let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        let paintedAlpha = try #require(alpha.first { $0 > 0 })

        #expect(alpha.contains(0))
        #expect((120...136).contains(Int(paintedAlpha)))
    }

    @Test func usePatternOffsetsShiftTheRenderedPatternPhase() throws {
        func appliedAlpha(offsetX: CGFloat) throws -> [UInt8] {
            let viewModel = ImageEditorViewModel(
                sourceName: "patch-pattern-offset.png",
                image: .transparent(size: CGSize(width: 16, height: 16))
            ) { _ in }
            viewModel.selectAll()
            viewModel.opacity = 1
            viewModel.patchPatternContent = ImageEditorPatternFillContent(
                kind: .checkerboard,
                red: 1,
                green: 0,
                blue: 0,
                opacity: 1,
                scale: 8,
                offsetX: offsetX
            )

            #expect(viewModel.applyPatchPattern())
            let image = try #require(viewModel.document.selectedLayer?.image)
            let pixels = try #require(imageEditorRGBABytes(image, width: 16, height: 16))
            return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        }

        let original = try appliedAlpha(offsetX: 0)
        let shifted = try appliedAlpha(offsetX: 2)
        func matchesShift(_ delta: Int) -> Bool {
            (0..<16).allSatisfy { y in
                (0..<16).allSatisfy { x in
                    shifted[y * 16 + x] == original[y * 16 + ((x + delta + 16) % 16)]
                }
            }
        }

        #expect(shifted != original)
        #expect(matchesShift(2) || matchesShift(-2))
        #expect(shifted.filter { $0 > 240 }.count == original.filter { $0 > 240 }.count)
    }

    @Test func resettingPatternOffsetIsIdempotentAndPreservesOtherSettings() {
        let viewModel = ImageEditorViewModel(
            sourceName: "patch-pattern-reset.png",
            image: .transparent(size: CGSize(width: 12, height: 12))
        ) { _ in }
        viewModel.patchPatternContent = ImageEditorPatternFillContent(
            kind: .dots,
            red: 0.2,
            green: 0.7,
            blue: 0.4,
            opacity: 0.35,
            scale: 24,
            scaleX: 1.75,
            scaleY: 0.6,
            angle: -37,
            flipsHorizontally: true,
            flipsVertically: true,
            offsetX: 18,
            offsetY: -11
        )
        viewModel.patchPatternBlendMode = .screen
        viewModel.patchPatternAlignsWithCanvas = false
        viewModel.patchPatternPreservesTransparency = true
        viewModel.patchPatternInvertsCoverage = true
        let historyCount = viewModel.document.history.count

        #expect(viewModel.resetPatchPatternOffset())
        #expect(viewModel.patchPatternContent.offsetX == 0)
        #expect(viewModel.patchPatternContent.offsetY == 0)
        #expect(viewModel.patchPatternContent.kind == .dots)
        #expect(viewModel.patchPatternContent.scale == 24)
        #expect(viewModel.patchPatternContent.scaleX == 1.75)
        #expect(viewModel.patchPatternContent.scaleY == 0.6)
        #expect(viewModel.patchPatternContent.opacity == 0.35)
        #expect(viewModel.patchPatternContent.angle == -37)
        #expect(viewModel.patchPatternContent.flipsHorizontally)
        #expect(viewModel.patchPatternContent.flipsVertically)
        #expect(viewModel.patchPatternContent.red == 0.2)
        #expect(viewModel.patchPatternContent.green == 0.7)
        #expect(viewModel.patchPatternContent.blue == 0.4)
        #expect(viewModel.patchPatternBlendMode == .screen)
        #expect(!viewModel.patchPatternAlignsWithCanvas)
        #expect(viewModel.patchPatternPreservesTransparency)
        #expect(viewModel.patchPatternInvertsCoverage)
        #expect(viewModel.document.history.count == historyCount)
        #expect(!viewModel.resetPatchPatternOffset())
    }

    @Test func usePatternBlendModeChangesTheRenderedPixels() throws {
        func appliedPixels(blendMode: ImageEditorBlendMode) throws -> [UInt8] {
            let source = NSImage.rendered(size: CGSize(width: 12, height: 12)) { rect in
                NSColor.blue.setFill()
                rect.fill()
            } ?? .transparent(size: CGSize(width: 12, height: 12))
            let viewModel = ImageEditorViewModel(
                sourceName: "patch-pattern-blend.png",
                image: source
            ) { _ in }
            viewModel.replaceSelectedLayerImageForTesting(
                source,
                historyTitle: L10n.text("imageEditor.history.brush")
            )
            viewModel.selectAll()
            viewModel.opacity = 1
            viewModel.patchPatternBlendMode = blendMode
            viewModel.patchPatternContent = ImageEditorPatternFillContent(
                kind: .checkerboard,
                red: 1,
                green: 0,
                blue: 0,
                opacity: 1,
                scale: 6
            )

            #expect(viewModel.applyPatchPattern())
            let image = try #require(viewModel.document.selectedLayer?.image)
            return try #require(imageEditorRGBABytes(image, width: 12, height: 12))
        }

        let normal = try appliedPixels(blendMode: .normal)
        let multiply = try appliedPixels(blendMode: .multiply)
        let paintedOffset = try #require(stride(from: 0, to: normal.count, by: 4).first {
            normal[$0] > 240 && normal[$0 + 2] < 15 && normal[$0 + 3] > 240
        })

        #expect(multiply[paintedOffset] < 15)
        #expect(multiply[paintedOffset + 1] < 15)
        #expect(multiply[paintedOffset + 2] < 15)
        #expect(multiply[paintedOffset + 3] > 240)
        #expect(Array(multiply[paintedOffset..<(paintedOffset + 4)])
            != Array(normal[paintedOffset..<(paintedOffset + 4)]))
    }

    @Test func usePatternCanSwitchBetweenCanvasAndLayerCoordinates() throws {
        func appliedPixels(alignsWithCanvas: Bool) throws -> [UInt8] {
            let size = CGSize(width: 24, height: 12)
            let source = NSImage.transparent(size: size)
            let viewModel = ImageEditorViewModel(
                sourceName: "patch-pattern-alignment.png",
                image: source
            ) { _ in }
            viewModel.replaceSelectedLayerImageForTesting(
                source,
                historyTitle: L10n.text("imageEditor.history.brush")
            )
            let layerIndex = try #require(viewModel.document.selectedLayerIndex)
            viewModel.document.layers[layerIndex].frame = CGRect(
                x: 5,
                y: 0,
                width: size.width,
                height: size.height
            )
            viewModel.selectAll()
            viewModel.opacity = 1
            viewModel.patchPatternAlignsWithCanvas = alignsWithCanvas
            viewModel.patchPatternContent = ImageEditorPatternFillContent(
                kind: .checkerboard,
                red: 1,
                green: 0,
                blue: 0,
                opacity: 1,
                scale: 12
            )

            #expect(viewModel.applyPatchPattern())
            let image = try #require(viewModel.document.selectedLayer?.image)
            return try #require(imageEditorRGBABytes(image, width: 24, height: 12))
        }

        let canvasAligned = try appliedPixels(alignsWithCanvas: true)
        let layerAligned = try appliedPixels(alignsWithCanvas: false)

        #expect(canvasAligned != layerAligned)
        let canvasAlpha = stride(from: 3, to: canvasAligned.count, by: 4).map { canvasAligned[$0] }
        let layerAlpha = stride(from: 3, to: layerAligned.count, by: 4).map { layerAligned[$0] }
        #expect(canvasAlpha != layerAlpha)
    }

    @Test func transparentOptionIsWiredToTheOptionsBarAndLivePreview() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let commandSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorSelectionEditCommands.swift"),
            encoding: .utf8
        )

        #expect(source.contains("isOn: $viewModel.patchTransparentEnabled"))
        #expect(source.contains(".accessibilityIdentifier(\"image-editor-patch-transparent\")"))
        #expect(source.contains(".onChange(of: viewModel.patchTransparentEnabled)"))
        #expect(source.contains("selection: $viewModel.patchSampleSource"))
        #expect(source.contains("ForEach(ImageEditorCloneSampleSource.allCases)"))
        #expect(source.contains("image-editor-patch-sample-source"))
        #expect(source.contains(".onChange(of: viewModel.patchSampleSource)"))
        #expect(source.contains("isOn: $viewModel.patchIgnoresAdjustmentLayers"))
        #expect(source.contains(".disabled(viewModel.patchSampleSource == .currentLayer)"))
        #expect(source.contains("image-editor-patch-ignore-adjustments"))
        #expect(source.contains(".onChange(of: viewModel.patchIgnoresAdjustmentLayers)"))
        #expect(source.contains("Stepper(value: $viewModel.patchDiffusion, in: 1...7)"))
        #expect(source.contains(".onChange(of: viewModel.patchDiffusion)"))
        #expect(source.contains("selection: $viewModel.patchPatternContent.kind"))
        #expect(source.contains("selection: $viewModel.patchPatternBlendMode"))
        #expect(source.contains("ForEach(ImageEditorBlendMode.smartFilterCases)"))
        #expect(source.contains("isOn: $viewModel.patchPatternAlignsWithCanvas"))
        #expect(source.contains("imageEditor.selectionFill.alignPatternWithCanvas"))
        #expect(source.contains("isOn: $viewModel.patchPatternPreservesTransparency"))
        #expect(source.contains("imageEditor.selectionFill.preserveTransparency"))
        #expect(source.contains("isOn: $viewModel.patchPatternInvertsCoverage"))
        #expect(source.contains("imageEditor.option.patchPatternInvertCoverage"))
        #expect(source.contains("isOn: $viewModel.patchPatternContent.flipsHorizontally"))
        #expect(source.contains("isOn: $viewModel.patchPatternContent.flipsVertically"))
        #expect(source.contains("imageEditor.option.patchPatternFlipHorizontal"))
        #expect(source.contains("imageEditor.option.patchPatternFlipVertical"))
        #expect(source.contains("value: $viewModel.patchPatternContent.scale"))
        #expect(source.contains("value: $viewModel.patchPatternContent.scaleX"))
        #expect(source.contains("value: $viewModel.patchPatternContent.scaleY"))
        #expect(source.contains("imageEditor.option.patchPatternScaleXValue"))
        #expect(source.contains("imageEditor.option.patchPatternScaleYValue"))
        #expect(source.contains("value: $viewModel.patchPatternContent.angle"))
        #expect(source.contains("value: $viewModel.patchPatternContent.opacity"))
        #expect(source.contains("value: $viewModel.patchPatternContent.offsetX"))
        #expect(source.contains("value: $viewModel.patchPatternContent.offsetY"))
        #expect(source.contains("selection: patchPatternColorBinding"))
        #expect(source.contains("imageEditor.option.patchPatternOpacityValue"))
        #expect(source.contains("imageEditor.patternFill.angleValue"))
        #expect(source.contains("imageEditor.option.patchPatternBlendMode"))
        #expect(source.contains("imageEditor.patternFill.offsetXValue"))
        #expect(source.contains("imageEditor.patternFill.offsetYValue"))
        #expect(source.contains("viewModel.resetPatchPatternOffset()"))
        #expect(source.contains("imageEditor.option.patchPatternSummary"))
        #expect(source.contains("viewModel.applyPatchPattern()"))
        #expect(source.contains("image-editor-patch-pattern-menu"))
        #expect(source.contains("image-editor-patch-pattern-scale"))
        #expect(source.contains("image-editor-patch-pattern-scale-x"))
        #expect(source.contains("image-editor-patch-pattern-scale-y"))
        #expect(source.contains("image-editor-patch-pattern-angle"))
        #expect(source.contains("image-editor-patch-pattern-opacity"))
        #expect(source.contains("image-editor-patch-pattern-blend-mode"))
        #expect(source.contains("image-editor-patch-pattern-align-canvas"))
        #expect(source.contains("image-editor-patch-pattern-preserve-transparency"))
        #expect(source.contains("image-editor-patch-pattern-invert-coverage"))
        #expect(source.contains("image-editor-patch-pattern-flip-horizontal"))
        #expect(source.contains("image-editor-patch-pattern-flip-vertical"))
        #expect(source.contains("image-editor-patch-pattern-offset-x"))
        #expect(source.contains("image-editor-patch-pattern-offset-y"))
        #expect(source.contains("image-editor-patch-pattern-reset-offset"))
        #expect(source.contains("image-editor-patch-pattern-color"))
        #expect(source.contains("image-editor-patch-use-pattern"))
        #expect(source.contains("refreshActivePatchPreview()"))
        #expect(commandSource.contains("blendMode: patchPatternBlendMode"))
        #expect(commandSource.contains("alignsWithCanvas: patchPatternAlignsWithCanvas"))
        #expect(commandSource.contains("let preservesTransparency = patchPatternPreservesTransparency"))
        #expect(commandSource.contains("invertsPatternCoverage: patchPatternInvertsCoverage"))
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
