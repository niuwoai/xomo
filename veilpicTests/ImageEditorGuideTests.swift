//
//  ImageEditorGuideTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorGuideTests {
    @Test
    func movingLayerSnapsBoundsToNearbyGuide() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        viewModel.addGuide(.vertical, at: 50)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 18, height: 0))
        viewModel.finishMovingSelectedLayer()

        let movedLayer = viewModel.document.layers[layerIndex]
        #expect(movedLayer.frame.maxX == 50)
        #expect(movedLayer.frame.origin.x == 30)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTranslate"))
    }

    @Test
    func movingLayerSnapsToOtherLayerWithoutManualGuide() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 120, height: 90))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        var targetLayer = ImageEditorLayer.blank(name: "Target", size: CGSize(width: 20, height: 20))
        targetLayer.frame = CGRect(x: 60, y: 30, width: 20, height: 20)
        viewModel.document.layers.append(targetLayer)
        #expect(viewModel.document.guides.isEmpty)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 27, height: 0))
        viewModel.finishMovingSelectedLayer()

        let movedLayer = viewModel.document.layers[layerIndex]
        #expect(movedLayer.frame.maxX == targetLayer.frame.minX)
        #expect(movedLayer.frame.origin.x == 40)
    }

    @Test
    func movingLayerSnapsToGridWhenGuideSnappingIsDisabled() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 13, y: 12, width: 20, height: 16)
        viewModel.document.gridSpacing = 20
        viewModel.toggleGuideSnapping()
        viewModel.toggleGridSnapping()

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 8, height: 0))
        viewModel.finishMovingSelectedLayer()

        let movedLayer = viewModel.document.layers[layerIndex]
        #expect(movedLayer.frame.origin.x == 20)
        #expect(movedLayer.frame.maxX == 40)
        #expect(viewModel.document.isGridVisible)
    }

    @Test
    func resizingLayerSnapsEdgeToNearbyGuide() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemPurple, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        viewModel.addGuide(.vertical, at: 50)

        viewModel.beginResizingSelectedLayer(handle: .right)
        viewModel.resizeSelectedLayer(to: CGPoint(x: 48, y: 20), handle: .right)
        viewModel.finishResizingSelectedLayer()

        let resizedLayer = viewModel.document.layers[layerIndex]
        #expect(resizedLayer.frame.minX == 10)
        #expect(resizedLayer.frame.maxX == 50)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerResize"))
    }

    @Test
    func resizingLayerSnapsToOtherLayerWithoutManualGuide() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemPurple, size: NSSize(width: 120, height: 90))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        var targetLayer = ImageEditorLayer.blank(name: "Target", size: CGSize(width: 20, height: 20))
        targetLayer.frame = CGRect(x: 50, y: 40, width: 20, height: 20)
        viewModel.document.layers.append(targetLayer)
        #expect(viewModel.document.guides.isEmpty)

        viewModel.beginResizingSelectedLayer(handle: .right)
        viewModel.resizeSelectedLayer(to: CGPoint(x: 48, y: 20), handle: .right)
        viewModel.finishResizingSelectedLayer()

        let resizedLayer = viewModel.document.layers[layerIndex]
        #expect(resizedLayer.frame.minX == 10)
        #expect(resizedLayer.frame.maxX == targetLayer.frame.minX)
    }

    @Test
    func resizingLayerSnapsEdgeToGridWhenGuideSnappingIsDisabled() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemPurple, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        viewModel.document.gridSpacing = 16
        viewModel.toggleGuideSnapping()
        viewModel.toggleGridSnapping()

        viewModel.beginResizingSelectedLayer(handle: .right)
        viewModel.resizeSelectedLayer(to: CGPoint(x: 47, y: 20), handle: .right)
        viewModel.finishResizingSelectedLayer()

        let resizedLayer = viewModel.document.layers[layerIndex]
        #expect(resizedLayer.frame.minX == 10)
        #expect(resizedLayer.frame.maxX == 48)
    }

    @Test
    func resizingLayerSnapsCenterToNearbyGuide() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemTeal, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        viewModel.addGuide(.vertical, at: 30)

        viewModel.beginResizingSelectedLayer(handle: .right)
        viewModel.resizeSelectedLayer(to: CGPoint(x: 46, y: 20), handle: .right)
        viewModel.finishResizingSelectedLayer()

        let resizedLayer = viewModel.document.layers[layerIndex]
        #expect(resizedLayer.frame.minX == 10)
        #expect(resizedLayer.frame.midX == 30)
        #expect(resizedLayer.frame.maxX == 50)
    }

    @Test
    func projectDocumentRoundTripsGuides() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemRed, size: NSSize(width: 120, height: 90))
        ) { _ in }
        viewModel.addGuide(.vertical, at: 30)
        viewModel.addGuide(.horizontal, at: 40)
        viewModel.toggleGuidesVisible()
        viewModel.toggleRulersVisible()
        viewModel.toggleGuideSnapping()
        viewModel.document.isGridVisible = true
        viewModel.document.isGridSnappingEnabled = true
        viewModel.document.gridSpacing = 24

        let data = try viewModel.projectData()
        let restoredViewModel = ImageEditorViewModel(
            sourceName: "empty.png",
            image: testImage(color: .black, size: NSSize(width: 12, height: 12))
        ) { _ in }
        try restoredViewModel.loadProjectData(data)

        #expect(restoredViewModel.document.guides.count == 2)
        #expect(restoredViewModel.document.guides[0].orientation == .vertical)
        #expect(restoredViewModel.document.guides[0].position == 30)
        #expect(restoredViewModel.document.guides[1].orientation == .horizontal)
        #expect(restoredViewModel.document.guides[1].position == 40)
        #expect(!restoredViewModel.document.areGuidesVisible)
        #expect(!restoredViewModel.document.areRulersVisible)
        #expect(!restoredViewModel.document.isGuideSnappingEnabled)
        #expect(restoredViewModel.document.isGridVisible)
        #expect(restoredViewModel.document.isGridSnappingEnabled)
        #expect(restoredViewModel.document.gridSpacing == 24)
    }

    @Test
    func movingGuideUpdatesPositionAndHistoryOnce() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemOrange, size: NSSize(width: 100, height: 80))
        ) { _ in }
        viewModel.addGuide(.vertical, at: 25)
        let guideID = try #require(viewModel.document.guides.first?.id)
        let historyCountBeforeMove = viewModel.document.history.count

        viewModel.beginMovingGuide(guideID)
        viewModel.moveGuide(guideID, to: 42)
        viewModel.moveGuide(guideID, to: 44)
        viewModel.finishMovingGuide()

        #expect(viewModel.document.guides.first?.position == 44)
        #expect(viewModel.document.history.count == historyCountBeforeMove + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.guideMove"))
        #expect(viewModel.canUndo)
    }

    @Test
    func resizingDocumentTransformsGuides() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemGreen, size: NSSize(width: 100, height: 80))
        ) { _ in }
        viewModel.addGuide(.vertical, at: 25)
        viewModel.addGuide(.horizontal, at: 20)

        viewModel.resizeImage(to: CGSize(width: 200, height: 160))

        #expect(viewModel.document.guides[0].position == 50)
        #expect(viewModel.document.guides[1].position == 40)

        viewModel.resizeCanvas(to: CGSize(width: 240, height: 200), anchor: .center)

        #expect(viewModel.document.guides[0].position == 70)
        #expect(viewModel.document.guides[1].position == 60)
    }

    private func testImage(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
}
