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
    func spacingGuideDistanceAndLabelFollowTheGuideAxisAndLocale() {
        let horizontal = ImageEditorSpacingGuide(
            orientation: .horizontal,
            start: CGPoint(x: 5, y: 12),
            end: CGPoint(x: 25, y: 99)
        )
        let reversedVertical = ImageEditorSpacingGuide(
            orientation: .vertical,
            start: CGPoint(x: 8, y: 42.25),
            end: CGPoint(x: 100, y: 30)
        )

        #expect(horizontal.distance == 20)
        #expect(horizontal.distanceText(locale: Locale(identifier: "en_US")) == "20")
        #expect(reversedVertical.distance == 12.25)
        #expect(reversedVertical.distanceText(locale: Locale(identifier: "en_US")) == "12.3")
        #expect(reversedVertical.distanceText(locale: Locale(identifier: "de_DE")) == "12,3")
    }

    @Test
    func spacingGuideLabelStaysInsideTheVisibleCanvasBounds() {
        #expect(
            ImageEditorSpacingGuideLabelLayout.clampedCoordinate(
                -5,
                minimum: 0,
                maximum: 100,
                badgeLength: 20
            ) == 10
        )
        #expect(
            ImageEditorSpacingGuideLabelLayout.clampedCoordinate(
                105,
                minimum: 0,
                maximum: 100,
                badgeLength: 20
            ) == 90
        )
        #expect(
            ImageEditorSpacingGuideLabelLayout.clampedCoordinate(
                0,
                minimum: 20,
                maximum: 30,
                badgeLength: 18
            ) == 25
        )
    }

    @Test
    func movingLayerSnapsBoundsToNearbyGuide() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        viewModel.addGuide(.vertical, at: 50)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 18, height: 0), snapping: true)
        viewModel.finishMovingSelectedLayer()

        let movedLayer = viewModel.document.layers[layerIndex]
        #expect(movedLayer.frame.maxX == 50)
        #expect(movedLayer.frame.origin.x == 30)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTranslate"))
    }

    @Test
    func movingLayerSnapsToOtherLayerWithoutManualGuide() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 120, height: 90))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        var targetLayer = ImageEditorLayer.blank(name: "Target", size: CGSize(width: 20, height: 20))
        targetLayer.frame = CGRect(x: 60, y: 30, width: 20, height: 20)
        viewModel.document.layers.append(targetLayer)
        #expect(viewModel.document.guides.isEmpty)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 27, height: 0), snapping: true)
        viewModel.finishMovingSelectedLayer()

        let movedLayer = viewModel.document.layers[layerIndex]
        #expect(movedLayer.frame.maxX == targetLayer.frame.minX)
        #expect(movedLayer.frame.origin.x == 40)
    }

    @Test
    func movingLayerSnapsBetweenHorizontalPeersAndShowsEqualSpacingGuides() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 160, height: 100))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 40, y: 20, width: 20, height: 20)
        var leftLayer = ImageEditorLayer.blank(name: "Left", size: CGSize(width: 20, height: 20))
        leftLayer.frame = CGRect(x: 10, y: 20, width: 20, height: 20)
        var rightLayer = ImageEditorLayer.blank(name: "Right", size: CGSize(width: 20, height: 20))
        rightLayer.frame = CGRect(x: 90, y: 20, width: 20, height: 20)
        viewModel.document.layers.append(contentsOf: [leftLayer, rightLayer])
        let historyCount = viewModel.document.history.count

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 8, height: 0), snapping: true)

        #expect(viewModel.movingObjectPreviewFrame?.minX == 50)
        #expect(viewModel.activeSpacingGuides.count == 2)
        #expect(viewModel.activeSpacingGuides.allSatisfy { $0.orientation == .horizontal })
        #expect(viewModel.activeSpacingGuides.map { $0.end.x - $0.start.x } == [20, 20])

        viewModel.finishMovingSelectedLayer()

        #expect(viewModel.document.layers[layerIndex].frame.minX == 50)
        #expect(viewModel.activeSpacingGuides.isEmpty)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTranslate"))
    }

    @Test
    func movingLayerRepeatsHorizontalSpacingAfterPeerPair() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 180, height: 100))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 110, y: 20, width: 15, height: 20)
        var firstLayer = ImageEditorLayer.blank(name: "First", size: CGSize(width: 20, height: 20))
        firstLayer.frame = CGRect(x: 10, y: 20, width: 20, height: 20)
        var secondLayer = ImageEditorLayer.blank(name: "Second", size: CGSize(width: 30, height: 20))
        secondLayer.frame = CGRect(x: 50, y: 20, width: 30, height: 20)
        viewModel.document.layers.append(contentsOf: [firstLayer, secondLayer])
        let historyCount = viewModel.document.history.count

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: -8, height: 0), snapping: true)

        #expect(viewModel.movingObjectPreviewFrame?.minX == 100)
        #expect(viewModel.activeSpacingGuides.count == 2)
        #expect(viewModel.activeSpacingGuides.map { $0.end.x - $0.start.x } == [20, 20])

        viewModel.finishMovingSelectedLayer()

        #expect(viewModel.document.layers[layerIndex].frame.minX == 100)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.activeSpacingGuides.isEmpty)
    }

    @Test
    func movingLayerRepeatsHorizontalSpacingBeforePeerPair() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemPurple, size: NSSize(width: 160, height: 100))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 0, y: 20, width: 20, height: 20)
        var firstLayer = ImageEditorLayer.blank(name: "First", size: CGSize(width: 20, height: 20))
        firstLayer.frame = CGRect(x: 50, y: 20, width: 20, height: 20)
        var secondLayer = ImageEditorLayer.blank(name: "Second", size: CGSize(width: 20, height: 20))
        secondLayer.frame = CGRect(x: 90, y: 20, width: 20, height: 20)
        viewModel.document.layers.append(contentsOf: [firstLayer, secondLayer])

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 8, height: 0), snapping: true)

        #expect(viewModel.movingObjectPreviewFrame?.minX == 10)
        #expect(viewModel.activeSpacingGuides.map { $0.end.x - $0.start.x } == [20, 20])

        #expect(viewModel.cancelMovingSelectedLayer())
        #expect(viewModel.document.layers[layerIndex].frame.minX == 0)
        #expect(viewModel.activeSpacingGuides.isEmpty)
    }

    @Test
    func movingLayerSnapsBetweenVerticalPeersAndShowsEqualSpacingGuides() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemTeal, size: NSSize(width: 100, height: 160))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 20, y: 40, width: 20, height: 20)
        var bottomLayer = ImageEditorLayer.blank(name: "Bottom", size: CGSize(width: 20, height: 20))
        bottomLayer.frame = CGRect(x: 20, y: 10, width: 20, height: 20)
        var topLayer = ImageEditorLayer.blank(name: "Top", size: CGSize(width: 20, height: 20))
        topLayer.frame = CGRect(x: 20, y: 90, width: 20, height: 20)
        viewModel.document.layers.append(contentsOf: [bottomLayer, topLayer])

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 0, height: 8), snapping: true)

        #expect(viewModel.movingObjectPreviewFrame?.minY == 50)
        #expect(viewModel.activeSpacingGuides.count == 2)
        #expect(viewModel.activeSpacingGuides.allSatisfy { $0.orientation == .vertical })
        #expect(viewModel.activeSpacingGuides.map { $0.end.y - $0.start.y } == [20, 20])

        #expect(viewModel.cancelMovingSelectedLayer())
        #expect(viewModel.document.layers[layerIndex].frame.minY == 40)
        #expect(viewModel.activeSpacingGuides.isEmpty)
    }

    @Test
    func movingLayerRepeatsVerticalSpacingAfterPeerPair() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemTeal, size: NSSize(width: 100, height: 160))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 20, y: 100, width: 20, height: 20)
        var firstLayer = ImageEditorLayer.blank(name: "First", size: CGSize(width: 20, height: 20))
        firstLayer.frame = CGRect(x: 20, y: 10, width: 20, height: 20)
        var secondLayer = ImageEditorLayer.blank(name: "Second", size: CGSize(width: 20, height: 20))
        secondLayer.frame = CGRect(x: 20, y: 50, width: 20, height: 20)
        viewModel.document.layers.append(contentsOf: [firstLayer, secondLayer])

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 0, height: -8), snapping: true)

        #expect(viewModel.movingObjectPreviewFrame?.minY == 90)
        #expect(viewModel.activeSpacingGuides.count == 2)
        #expect(viewModel.activeSpacingGuides.map { $0.end.y - $0.start.y } == [20, 20])

        viewModel.finishMovingSelectedLayer()
        #expect(viewModel.document.layers[layerIndex].frame.minY == 90)
        #expect(viewModel.activeSpacingGuides.isEmpty)
    }

    @Test
    func movingLayerRepeatsVerticalSpacingBeforePeerPair() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemYellow, size: NSSize(width: 100, height: 160))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 20, y: 0, width: 20, height: 20)
        var firstLayer = ImageEditorLayer.blank(name: "First", size: CGSize(width: 20, height: 20))
        firstLayer.frame = CGRect(x: 20, y: 50, width: 20, height: 20)
        var secondLayer = ImageEditorLayer.blank(name: "Second", size: CGSize(width: 20, height: 20))
        secondLayer.frame = CGRect(x: 20, y: 90, width: 20, height: 20)
        viewModel.document.layers.append(contentsOf: [firstLayer, secondLayer])

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 0, height: 8), snapping: true)

        #expect(viewModel.movingObjectPreviewFrame?.minY == 10)
        #expect(viewModel.activeSpacingGuides.count == 2)
        #expect(viewModel.activeSpacingGuides.map { $0.end.y - $0.start.y } == [20, 20])

        #expect(viewModel.cancelMovingSelectedLayer())
        #expect(viewModel.document.layers[layerIndex].frame.minY == 0)
        #expect(viewModel.activeSpacingGuides.isEmpty)
    }

    @Test
    func equalSpacingSnapIgnoresPeersFromOtherRows() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemIndigo, size: NSSize(width: 160, height: 120))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 40, y: 20, width: 20, height: 20)
        var leftLayer = ImageEditorLayer.blank(name: "Left", size: CGSize(width: 20, height: 20))
        leftLayer.frame = CGRect(x: 10, y: 20, width: 20, height: 20)
        var unrelatedLayer = ImageEditorLayer.blank(name: "Other Row", size: CGSize(width: 20, height: 20))
        unrelatedLayer.frame = CGRect(x: 55, y: 80, width: 20, height: 20)
        var rightLayer = ImageEditorLayer.blank(name: "Right", size: CGSize(width: 20, height: 20))
        rightLayer.frame = CGRect(x: 90, y: 20, width: 20, height: 20)
        viewModel.document.layers.append(contentsOf: [leftLayer, unrelatedLayer, rightLayer])

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 8, height: 0), snapping: true)

        #expect(viewModel.movingObjectPreviewFrame?.minX == 50)
        #expect(viewModel.activeSpacingGuides.count == 2)
    }

    @Test
    func repeatedSpacingSnapIgnoresPeerPairsFromOtherRows() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBrown, size: NSSize(width: 160, height: 120))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 100, y: 20, width: 20, height: 20)
        var firstLayer = ImageEditorLayer.blank(name: "First", size: CGSize(width: 20, height: 20))
        firstLayer.frame = CGRect(x: 10, y: 80, width: 20, height: 20)
        var secondLayer = ImageEditorLayer.blank(name: "Second", size: CGSize(width: 20, height: 20))
        secondLayer.frame = CGRect(x: 50, y: 80, width: 20, height: 20)
        viewModel.document.layers.append(contentsOf: [firstLayer, secondLayer])

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: -8, height: 0), snapping: true)

        #expect(viewModel.movingObjectPreviewFrame?.minX == 92)
        #expect(viewModel.activeSpacingGuides.isEmpty)
    }

    @Test
    func disablingSmartGuidesAlsoDisablesEqualSpacingSnap() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemOrange, size: NSSize(width: 160, height: 100))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 40, y: 20, width: 20, height: 20)
        var leftLayer = ImageEditorLayer.blank(name: "Left", size: CGSize(width: 20, height: 20))
        leftLayer.frame = CGRect(x: 10, y: 20, width: 20, height: 20)
        var rightLayer = ImageEditorLayer.blank(name: "Right", size: CGSize(width: 20, height: 20))
        rightLayer.frame = CGRect(x: 90, y: 20, width: 20, height: 20)
        viewModel.document.layers.append(contentsOf: [leftLayer, rightLayer])
        viewModel.toggleGuideSnapping()

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 8, height: 0), snapping: true)

        #expect(viewModel.movingObjectPreviewFrame?.minX == 48)
        #expect(viewModel.activeSpacingGuides.isEmpty)
    }

    @Test
    func classicAlignmentWinsWhenItsCorrectionTiesEqualSpacing() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemPink, size: NSSize(width: 160, height: 100))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 40, y: 20, width: 20, height: 20)
        var leftLayer = ImageEditorLayer.blank(name: "Left", size: CGSize(width: 20, height: 20))
        leftLayer.frame = CGRect(x: 10, y: 20, width: 20, height: 20)
        var rightLayer = ImageEditorLayer.blank(name: "Right", size: CGSize(width: 20, height: 20))
        rightLayer.frame = CGRect(x: 90, y: 20, width: 20, height: 20)
        viewModel.document.layers.append(contentsOf: [leftLayer, rightLayer])
        viewModel.addGuide(.vertical, at: 50)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 8, height: 0), snapping: true)

        #expect(viewModel.movingObjectPreviewFrame?.minX == 50)
        #expect(viewModel.activeSpacingGuides.isEmpty)
        #expect(viewModel.activeAlignmentGuides.contains {
            $0.orientation == .vertical && $0.position == 50
        })
    }

    @Test
    func horizontalConstraintKeepsSpacingGuidesOnTheConstrainedPreviewRow() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemGreen, size: NSSize(width: 160, height: 120))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 40, y: 20, width: 20, height: 20)
        var leftLayer = ImageEditorLayer.blank(name: "Left", size: CGSize(width: 20, height: 100))
        leftLayer.frame = CGRect(x: 10, y: 0, width: 20, height: 100)
        var rightLayer = ImageEditorLayer.blank(name: "Right", size: CGSize(width: 20, height: 100))
        rightLayer.frame = CGRect(x: 90, y: 0, width: 20, height: 100)
        viewModel.document.layers.append(contentsOf: [leftLayer, rightLayer])

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(
            by: CGSize(width: 8, height: 3),
            snapping: true,
            constrainingTo: .horizontal
        )

        #expect(viewModel.movingObjectPreviewFrame == CGRect(x: 50, y: 20, width: 20, height: 20))
        #expect(viewModel.activeSpacingGuides.count == 2)
        #expect(viewModel.activeSpacingGuides.allSatisfy {
            $0.orientation == .horizontal && $0.start.y == 30 && $0.end.y == 30
        })
    }

    @Test
    func movingOrdinaryLayerSnapsToCanvasCenterWithoutManualGuide() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 120, height: 90))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 35, y: 12, width: 20, height: 16)
        #expect(viewModel.document.guides.isEmpty)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 14, height: 0), snapping: true)

        #expect(viewModel.movingObjectPreviewFrame?.midX == viewModel.document.canvasSize.width * 0.5)
        #expect(viewModel.activeAlignmentGuides.contains {
            $0.orientation == .vertical
                && $0.position == viewModel.document.canvasSize.width * 0.5
        })

        viewModel.finishMovingSelectedLayer()
        #expect(
            viewModel.document.layers[layerIndex].frame.midX
                == viewModel.document.canvasSize.width * 0.5
        )
    }

    @Test
    func movingLayerExposesComponentAlignmentGuidesUntilTheMoveFinishes() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 140, height: 100))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        var targetLayer = ImageEditorLayer.blank(name: "Target", size: CGSize(width: 30, height: 24))
        targetLayer.image = testImage(
            color: .systemYellow,
            size: CGSize(width: 30, height: 24)
        )
        targetLayer.frame = CGRect(x: 60, y: 42, width: 30, height: 24)
        viewModel.document.layers.append(targetLayer)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 27, height: 30), snapping: true)

        #expect(viewModel.activeAlignmentGuides.contains {
            $0.orientation == .vertical && $0.position == targetLayer.frame.minX
        })
        #expect(viewModel.activeAlignmentGuides.contains {
            $0.orientation == .horizontal && $0.position == targetLayer.frame.minY
        })

        viewModel.finishMovingSelectedLayer()
        #expect(viewModel.activeAlignmentGuides.isEmpty)
    }

    @Test
    func movingLayerSnapsToGridWhenGuideSnappingIsDisabled() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 13, y: 12, width: 20, height: 16)
        viewModel.document.gridSpacing = 20
        viewModel.toggleGuideSnapping()
        viewModel.toggleGridSnapping()

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 8, height: 0), snapping: true)
        viewModel.finishMovingSelectedLayer()

        let movedLayer = viewModel.document.layers[layerIndex]
        #expect(movedLayer.frame.origin.x == 20)
        #expect(movedLayer.frame.maxX == 40)
        #expect(viewModel.document.isGridVisible)
    }

    @Test
    func resizingLayerSnapsEdgeToNearbyGuide() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemPurple, size: NSSize(width: 100, height: 80))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        viewModel.addGuide(.vertical, at: 50)

        viewModel.beginResizingSelectedLayer(handle: .right)
        viewModel.resizeSelectedLayer(to: CGPoint(x: 48, y: 20), handle: .right)

        #expect(viewModel.activeAlignmentGuides == [
            ImageEditorAlignmentGuide(orientation: .vertical, position: 50)
        ])

        viewModel.finishResizingSelectedLayer()

        let resizedLayer = viewModel.document.layers[layerIndex]
        #expect(resizedLayer.frame.minX == 10)
        #expect(resizedLayer.frame.maxX == 50)
        #expect(viewModel.activeAlignmentGuides.isEmpty)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerResize"))
    }

    @Test
    func resizingComponentSnapsBothAxesAndShowsSmartGuidesUntilTransformEnds() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .windowBackgroundColor, size: NSSize(width: 360, height: 240))
        ) { _ in }
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 90, y: 80))
        let initialFrame = try #require(viewModel.selectedXomoObjectFrame)
        viewModel.addGuide(.vertical, at: initialFrame.maxX + 20)
        viewModel.addGuide(.horizontal, at: initialFrame.maxY + 16)
        let verticalGuide = try #require(
            viewModel.document.guides.first { $0.orientation == .vertical }?.position
        )
        let horizontalGuide = try #require(
            viewModel.document.guides.first { $0.orientation == .horizontal }?.position
        )

        viewModel.beginResizingSelectedLayer(handle: .topRight)
        viewModel.resizeSelectedLayer(
            to: CGPoint(x: verticalGuide - 2, y: horizontalGuide - 2),
            handle: .topRight
        )

        #expect(viewModel.activeAlignmentGuides == [
            ImageEditorAlignmentGuide(orientation: .vertical, position: verticalGuide),
            ImageEditorAlignmentGuide(orientation: .horizontal, position: horizontalGuide)
        ])
        #expect(viewModel.selectedXomoObjectFrame?.maxX == verticalGuide)
        #expect(viewModel.selectedXomoObjectFrame?.maxY == horizontalGuide)

        viewModel.finishResizingSelectedLayer()
        #expect(viewModel.activeAlignmentGuides.isEmpty)
    }

    @Test
    func resizeSmartGuidesClearForAspectRatioModeAndCancellation() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemIndigo, size: NSSize(width: 120, height: 90))
        )
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        let originalFrame = CGRect(x: 10, y: 12, width: 20, height: 16)
        viewModel.document.layers[layerIndex].frame = originalFrame
        viewModel.addGuide(.vertical, at: 50)

        viewModel.beginResizingSelectedLayer(handle: .right)
        viewModel.resizeSelectedLayer(to: CGPoint(x: 48, y: 20), handle: .right)
        #expect(!viewModel.activeAlignmentGuides.isEmpty)

        viewModel.resizeSelectedLayer(
            to: CGPoint(x: 48, y: 20),
            handle: .right,
            preservingAspectRatio: true
        )
        #expect(viewModel.activeAlignmentGuides.isEmpty)

        viewModel.resizeSelectedLayer(to: CGPoint(x: 48, y: 20), handle: .right)
        #expect(!viewModel.activeAlignmentGuides.isEmpty)
        #expect(viewModel.cancelTransformingSelectedLayer())
        #expect(viewModel.activeAlignmentGuides.isEmpty)
        #expect(viewModel.document.layers[layerIndex].frame == originalFrame)
    }

    @Test
    func resizingLayerSnapsToOtherLayerWithoutManualGuide() throws {
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemPurple, size: NSSize(width: 120, height: 90))
        )
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
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemPurple, size: NSSize(width: 100, height: 80))
        )
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
        let viewModel = transformableViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemTeal, size: NSSize(width: 100, height: 80))
        )
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
        viewModel.toggleGuidesLocked()
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
        #expect(restoredViewModel.document.areGuidesLocked)
        #expect(restoredViewModel.document.isGridVisible)
        #expect(restoredViewModel.document.isGridSnappingEnabled)
        #expect(restoredViewModel.document.gridSpacing == 24)
    }

    @Test
    func lockingGuidesPreventsAccidentalMovesWithoutRemovingGuides() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemOrange, size: NSSize(width: 100, height: 80))
        ) { _ in }
        viewModel.addGuide(.vertical, at: 25)
        let guideID = try #require(viewModel.document.guides.first?.id)
        let historyCountBeforeLock = viewModel.document.history.count

        viewModel.toggleGuidesLocked()
        viewModel.beginMovingGuide(guideID)
        viewModel.moveGuide(guideID, to: 44)
        viewModel.finishMovingGuide()

        #expect(viewModel.document.areGuidesLocked)
        #expect(viewModel.document.guides.first?.position == 25)
        #expect(viewModel.document.guides.count == 1)
        #expect(viewModel.document.history.count == historyCountBeforeLock + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.guidesLocking"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.guidesLocked"))

        viewModel.toggleGuidesLocked()
        viewModel.beginMovingGuide(guideID)
        viewModel.moveGuide(guideID, to: 44)
        viewModel.finishMovingGuide()

        #expect(!viewModel.document.areGuidesLocked)
        #expect(viewModel.document.guides.first?.position == 44)
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

    private func transformableViewModel(
        sourceName: String,
        image: NSImage
    ) -> ImageEditorViewModel {
        let viewModel = ImageEditorViewModel(sourceName: sourceName, image: image) { _ in }
        if let selectedIndex = viewModel.document.selectedLayerIndex {
            viewModel.document.layers[selectedIndex].image = image
        }
        return viewModel
    }
}
