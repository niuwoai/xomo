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

    @Test func patchToolCanCreateAReplacementLassoBeforeDragging() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.selectionMode = .add
        viewModel.createRectSelection(from: CGPoint(x: 2, y: 2), to: CGPoint(x: 8, y: 8))
        let points = [
            CGPoint(x: 30, y: 20),
            CGPoint(x: 50, y: 20),
            CGPoint(x: 50, y: 40),
            CGPoint(x: 30, y: 40)
        ]

        viewModel.createPatchSelection(points: points)

        #expect(viewModel.selectionMode == .add)
        #expect(viewModel.document.selection?.bounds == CGRect(x: 30, y: 20, width: 20, height: 20))
        #expect(viewModel.canBeginPatch(at: CGPoint(x: 40, y: 30)))
        #expect(!viewModel.canBeginPatch(at: CGPoint(x: 4, y: 4)))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.patchSelectionReady"))
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
