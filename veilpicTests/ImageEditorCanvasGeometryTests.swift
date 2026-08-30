//
//  ImageEditorCanvasGeometryTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/10.
//

import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import musepic

struct ImageEditorCanvasGeometryTests {
    @Test
    func transformsPointsAndRectsUsingCanvasDimensionsOnly() throws {
        let canvasSize = CGSize(width: 400, height: 200)
        let viewportSize = CGSize(width: 1_000, height: 600)
        let imageRect = ImageEditorCanvasGeometry.fittedImageRect(
            canvasSize: canvasSize,
            viewportSize: viewportSize,
            zoom: 1,
            canvasOffset: CGSize(width: 20, height: -10)
        )

        assertEqual(imageRect, CGRect(x: 150, y: 105, width: 740, height: 370))

        let imagePoint = try #require(ImageEditorCanvasGeometry.imagePoint(
            from: CGPoint(x: 224, y: 142),
            imageRect: imageRect,
            canvasSize: canvasSize
        ))
        assertEqual(imagePoint, CGPoint(x: 40, y: 20))

        let outsidePoint = ImageEditorCanvasGeometry.unboundedImagePoint(
            from: CGPoint(x: 76, y: 86.5),
            imageRect: imageRect,
            canvasSize: canvasSize
        )
        assertEqual(outsidePoint, CGPoint(x: -40, y: -10))

        let viewRect = ImageEditorCanvasGeometry.viewRect(
            from: CGRect(x: 40, y: 20, width: 120, height: 60),
            imageRect: imageRect,
            canvasSize: canvasSize
        )
        assertEqual(viewRect, CGRect(x: 224, y: 142, width: 222, height: 111))
    }

    @Test
    func navigatorViewportTracksZoomAndPanInsideThumbnail() throws {
        let canvasSize = CGSize(width: 400, height: 200)
        let previewBounds = CGRect(x: 0, y: 0, width: 184, height: 92)
        let fullViewport = ImageEditorCanvasGeometry.navigatorViewportRect(
            canvasSize: canvasSize,
            canvasViewportSize: CGSize(width: 800, height: 600),
            zoom: 1,
            canvasOffset: .zero,
            previewBounds: previewBounds
        )
        let full = try #require(fullViewport)
        assertEqual(full, previewBounds)

        let zoomedViewport = ImageEditorCanvasGeometry.navigatorViewportRect(
            canvasSize: canvasSize,
            canvasViewportSize: CGSize(width: 800, height: 600),
            zoom: 2,
            canvasOffset: CGSize(width: -120, height: 40),
            previewBounds: previewBounds
        )
        let zoomed = try #require(zoomedViewport)
        #expect(zoomed.width < previewBounds.width)
        #expect(zoomed.height < previewBounds.height)
        #expect(zoomed.minX >= previewBounds.minX)
        #expect(zoomed.maxX <= previewBounds.maxX)
        #expect(zoomed.minY >= previewBounds.minY)
        #expect(zoomed.maxY <= previewBounds.maxY)
    }

    @Test
    func visibleCanvasCenterTracksZoomAndPanAndStaysInsideCanvas() {
        let canvasSize = CGSize(width: 400, height: 200)
        let viewportSize = CGSize(width: 1_000, height: 600)

        assertEqual(
            ImageEditorCanvasGeometry.visibleCanvasCenter(
                canvasSize: canvasSize,
                viewportSize: viewportSize,
                zoom: 1,
                canvasOffset: .zero
            ),
            CGPoint(x: 200, y: 100)
        )
        assertEqual(
            ImageEditorCanvasGeometry.visibleCanvasCenter(
                canvasSize: canvasSize,
                viewportSize: viewportSize,
                zoom: 2,
                canvasOffset: CGSize(width: -120, height: 40)
            ),
            CGPoint(x: 232.432_432, y: 89.189_189)
        )
        assertEqual(
            ImageEditorCanvasGeometry.visibleCanvasCenter(
                canvasSize: canvasSize,
                viewportSize: viewportSize,
                zoom: 2,
                canvasOffset: CGSize(width: 10_000, height: -10_000)
            ),
            CGPoint(x: 0, y: 200)
        )
        assertEqual(
            ImageEditorCanvasGeometry.visibleCanvasCenter(
                canvasSize: canvasSize,
                viewportSize: .zero,
                zoom: 2,
                canvasOffset: CGSize(width: 100, height: 100)
            ),
            CGPoint(x: 200, y: 100)
        )
    }

    @Test
    func marchingAntsDashPhaseWrapsAndHandlesNegativeTime() {
        let patternLength = ImageEditorSelectionMarchingAnts.patternLength
        #expect(ImageEditorSelectionMarchingAnts.dashPhase(at: 0) == 0)
        #expect(abs(ImageEditorSelectionMarchingAnts.dashPhase(at: 0.18) - patternLength / 4) < 0.001)
        #expect(abs(ImageEditorSelectionMarchingAnts.dashPhase(at: 0.72)) < 0.001)
        #expect(abs(ImageEditorSelectionMarchingAnts.dashPhase(at: -0.18) - patternLength * 3 / 4) < 0.001)
        #expect(ImageEditorSelectionMarchingAnts.dashPhase(at: .infinity) == 0)
    }

    @Test
    func cropGeometryMovesAndResizesWithinCanvasBounds() {
        let crop = CGRect(x: 20, y: 30, width: 80, height: 60)
        #expect(
            ImageEditorCropGeometry.hitHandle(
                at: CGPoint(x: 21, y: 60),
                in: crop,
                tolerance: 3
            ) == .left
        )
        #expect(
            ImageEditorCropGeometry.hitHandle(
                at: CGPoint(x: 55, y: 55),
                in: crop,
                tolerance: 3
            ) == .move
        )

        let moved = ImageEditorCropGeometry.adjustedFrame(
            from: crop,
            handle: .move,
            delta: CGSize(width: 500, height: -500),
            canvasSize: CGSize(width: 160, height: 120)
        )
        #expect(moved == CGRect(x: 80, y: 0, width: 80, height: 60))

        let resized = ImageEditorCropGeometry.adjustedFrame(
            from: crop,
            handle: .topLeft,
            delta: CGSize(width: -40, height: -50),
            canvasSize: CGSize(width: 160, height: 120)
        )
        #expect(resized == CGRect(x: 0, y: 0, width: 100, height: 90))
        #expect(resized.maxX == crop.maxX)
        #expect(resized.maxY == crop.maxY)

        let minimum = ImageEditorCropGeometry.adjustedFrame(
            from: crop,
            handle: .right,
            delta: CGSize(width: -500, height: 0),
            canvasSize: CGSize(width: 160, height: 120)
        )
        #expect(minimum.width == 4)
        #expect(minimum.maxX == crop.minX + 4)

        let ratioCrop = CGRect(x: 20, y: 30, width: 80, height: 40)
        let lockedCorner = ImageEditorCropGeometry.adjustedFrame(
            from: ratioCrop,
            handle: .bottomRight,
            delta: CGSize(width: 40, height: 10),
            canvasSize: CGSize(width: 200, height: 150),
            preservesAspectRatio: true
        )
        #expect(lockedCorner == CGRect(x: 20, y: 30, width: 116, height: 58))
        #expect(lockedCorner.width / lockedCorner.height == 2)

        let lockedRight = ImageEditorCropGeometry.adjustedFrame(
            from: ratioCrop,
            handle: .right,
            delta: CGSize(width: 40, height: 0),
            canvasSize: CGSize(width: 200, height: 150),
            preservesAspectRatio: true
        )
        #expect(lockedRight == CGRect(x: 20, y: 20, width: 120, height: 60))
        #expect(lockedRight.midY == ratioCrop.midY)

        let lockedTop = ImageEditorCropGeometry.adjustedFrame(
            from: ratioCrop,
            handle: .top,
            delta: CGSize(width: 0, height: -20),
            canvasSize: CGSize(width: 200, height: 150),
            preservesAspectRatio: true
        )
        #expect(lockedTop == CGRect(x: 0, y: 10, width: 120, height: 60))
        #expect(lockedTop.midX == ratioCrop.midX)

        let lockedAtCanvasEdge = ImageEditorCropGeometry.adjustedFrame(
            from: CGRect(x: 20, y: 5, width: 80, height: 40),
            handle: .right,
            delta: CGSize(width: 100, height: 0),
            canvasSize: CGSize(width: 200, height: 60),
            preservesAspectRatio: true
        )
        #expect(lockedAtCanvasEdge == CGRect(x: 20, y: 0, width: 100, height: 50))
    }

    @Test
    func pendingCropMetricsMatchCommittedOutwardPixelRoundingAndCanvasBounds() throws {
        #expect(ImageEditorCropGeometry.fullCanvasFrame(
            canvasSize: CGSize(width: 200, height: 150)
        ) == CGRect(x: 0, y: 0, width: 200, height: 150))
        #expect(ImageEditorCropGeometry.fullCanvasFrame(
            canvasSize: CGSize(width: -20, height: 80)
        ) == CGRect(x: 0, y: 0, width: 0, height: 80))
        #expect(ImageEditorCropGeometry.committedPixelBounds(
            for: CGRect(x: 10.2, y: 20.7, width: 100.1, height: 80.2),
            canvasSize: CGSize(width: 200, height: 150)
        ) == CGRect(x: 10, y: 20, width: 101, height: 81))
        #expect(ImageEditorCropGeometry.committedPixelBounds(
            for: CGRect(x: -4.6, y: 145.2, width: 20.1, height: 20.1),
            canvasSize: CGSize(width: 200, height: 150)
        ) == CGRect(x: 0, y: 145, width: 16, height: 5))
        #expect(ImageEditorCropGeometry.frameBySettingCommittedOrigin(
            of: CGRect(x: 10.2, y: 20.7, width: 100.1, height: 80.2),
            to: CGPoint(x: 50, y: 40),
            canvasSize: CGSize(width: 200, height: 150)
        ) == CGRect(x: 50, y: 40, width: 101, height: 81))
        #expect(ImageEditorCropGeometry.frameBySettingCommittedOrigin(
            of: CGRect(x: 10.2, y: 20.7, width: 100.1, height: 80.2),
            to: CGPoint(x: 150, y: -20),
            canvasSize: CGSize(width: 200, height: 150)
        ) == CGRect(x: 99, y: 0, width: 101, height: 81))
        #expect(ImageEditorCropGeometry.frameBySettingCommittedSize(
            of: CGRect(x: 10.2, y: 20.7, width: 100.1, height: 80.2),
            to: CGSize(width: 72.4, height: 48.6),
            canvasSize: CGSize(width: 200, height: 150)
        ) == CGRect(x: 10, y: 20, width: 72, height: 49))
        #expect(ImageEditorCropGeometry.frameBySettingCommittedSize(
            of: CGRect(x: 10.2, y: 20.7, width: 100.1, height: 80.2),
            to: CGSize(width: 500, height: 2),
            canvasSize: CGSize(width: 200, height: 150)
        ) == CGRect(x: 10, y: 20, width: 190, height: 8))
        #expect(ImageEditorCropGeometry.frameBySwappingCommittedDimensions(
            of: CGRect(x: 50, y: 40, width: 100, height: 50),
            canvasSize: CGSize(width: 300, height: 250)
        ) == CGRect(x: 75, y: 15, width: 50, height: 100))
        #expect(ImageEditorCropGeometry.frameBySwappingCommittedDimensions(
            of: CGRect(x: 10, y: 20, width: 100, height: 50),
            canvasSize: CGSize(width: 200, height: 150)
        ) == CGRect(x: 35, y: 0, width: 50, height: 100))
        #expect(ImageEditorCropGeometry.frameBySwappingCommittedDimensions(
            of: CGRect(x: 20, y: 10, width: 180, height: 40),
            canvasSize: CGSize(width: 200, height: 100)
        ) == CGRect(x: 99, y: 0, width: 22, height: 100))
        #expect(ImageEditorCropAspectPreset.original.components(
            canvasSize: CGSize(width: 4032, height: 3024)
        ) == CGSize(width: 4, height: 3))
        #expect(ImageEditorCropAspectPreset.original.components(
            canvasSize: CGSize(width: 0, height: 3024)
        ) == nil)
        #expect(ImageEditorCropAspectPreset.free.components(
            canvasSize: CGSize(width: 200, height: 150)
        ) == nil)
        let presetCrop = CGRect(x: 10, y: 20, width: 100, height: 80)
        #expect(ImageEditorCropGeometry.frameByApplyingAspectRatio(
            of: presetCrop,
            components: CGSize(width: 1, height: 1),
            canvasSize: CGSize(width: 200, height: 150)
        ) == CGRect(x: 20, y: 20, width: 80, height: 80))
        #expect(ImageEditorCropGeometry.frameByApplyingAspectRatio(
            of: presetCrop,
            components: CGSize(width: 4, height: 3),
            canvasSize: CGSize(width: 200, height: 150)
        ) == CGRect(x: 10, y: 23, width: 100, height: 75))
        #expect(ImageEditorCropGeometry.frameByApplyingAspectRatio(
            of: presetCrop,
            components: CGSize(width: 16, height: 9),
            canvasSize: CGSize(width: 200, height: 150)
        ) == CGRect(x: 12, y: 33, width: 96, height: 54))
        let ratioCrop = CGRect(x: 10, y: 20, width: 100, height: 50)
        #expect(ImageEditorCropGeometry.frameBySettingCommittedDimension(
            of: ratioCrop,
            dimension: .width,
            value: 80,
            canvasSize: CGSize(width: 200, height: 150),
            preservesAspectRatio: true
        ) == CGRect(x: 10, y: 20, width: 80, height: 40))
        #expect(ImageEditorCropGeometry.frameBySettingCommittedDimension(
            of: ratioCrop,
            dimension: .height,
            value: 60,
            canvasSize: CGSize(width: 200, height: 150),
            preservesAspectRatio: true
        ) == CGRect(x: 10, y: 20, width: 120, height: 60))
        #expect(ImageEditorCropGeometry.frameBySettingCommittedDimension(
            of: ratioCrop,
            dimension: .width,
            value: 500,
            canvasSize: CGSize(width: 200, height: 150),
            preservesAspectRatio: true
        ) == CGRect(x: 10, y: 20, width: 190, height: 95))

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let commandSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorCanvasCommands.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("ImageEditorCropGeometry.committedPixelBounds"))
        #expect(viewSource.contains("setPendingCropOrigin(x:"))
        #expect(viewSource.contains("setPendingCropOrigin(y:"))
        #expect(viewSource.contains("image-editor-crop-origin-x"))
        #expect(viewSource.contains("image-editor-crop-origin-y"))
        #expect(viewSource.contains("setPendingCropSize(width:"))
        #expect(viewSource.contains("setPendingCropSize(height:"))
        #expect(viewSource.contains("image-editor-crop-width"))
        #expect(viewSource.contains("image-editor-crop-height"))
        #expect(
            viewSource.components(separatedBy: "preservesAspectRatio: isCropAspectRatioLocked").count == 3
        )
        #expect(viewSource.contains("image-editor-crop-aspect-ratio-lock"))
        #expect(viewSource.contains("ImageEditorCropGeometry.fullCanvasFrame"))
        #expect(viewSource.contains(".disabled(pixelBounds == ImageEditorCropGeometry.fullCanvasFrame"))
        #expect(viewSource.contains("image-editor-crop-reset"))
        #expect(viewSource.contains("frameBySwappingCommittedDimensions"))
        #expect(viewSource.contains(".disabled(pixelBounds.width == pixelBounds.height)"))
        #expect(viewSource.contains("image-editor-crop-swap-dimensions"))
        #expect(viewSource.contains("ImageEditorCropAspectPreset.allCases"))
        #expect(viewSource.contains("applyCropAspectPreset(preset)"))
        #expect(viewSource.contains("isCropAspectRatioLocked = true"))
        #expect(viewSource.contains("isCropAspectRatioLocked = false"))
        #expect(viewSource.contains("image-editor-crop-aspect-menu"))
        #expect(commandSource.contains("ImageEditorCropGeometry.committedPixelBounds"))

        for localizationID in ["zh-Hans", "en", "ja"] {
            let localization = try String(
                contentsOf: repositoryRoot
                    .appendingPathComponent("veilpic/\(localizationID).lproj/Localizable.strings"),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.cropBounds.xHelp\""))
            #expect(localization.contains("\"imageEditor.cropBounds.yHelp\""))
            #expect(localization.contains("\"imageEditor.cropBounds.widthHelp\""))
            #expect(localization.contains("\"imageEditor.cropBounds.heightHelp\""))
            #expect(localization.contains("\"imageEditor.cropBounds.aspectLock\""))
            #expect(localization.contains("\"imageEditor.cropBounds.aspectUnlock\""))
            #expect(localization.contains("\"imageEditor.cropBounds.resetHelp\""))
            #expect(localization.contains("\"imageEditor.cropBounds.swapHelp\""))
            #expect(localization.contains("\"imageEditor.cropAspect.help\""))
            #expect(localization.contains("\"imageEditor.cropAspect.original\""))
            #expect(localization.contains("\"imageEditor.cropAspect.square\""))
            #expect(localization.contains("\"imageEditor.cropAspect.fourThree\""))
            #expect(localization.contains("\"imageEditor.cropAspect.threeTwo\""))
            #expect(localization.contains("\"imageEditor.cropAspect.sixteenNine\""))
            #expect(localization.contains("\"imageEditor.cropAspect.free\""))
        }
    }

    @Test
    func pendingCropDoubleClickCommitsOnlyAnUnmodifiedInteriorClick() throws {
        #expect(ImageEditorCropDoubleClickCommitPolicy.shouldCommit(
            activeHandle: .move,
            clickCount: 2,
            viewTranslation: .zero,
            hasConflictingModifiers: false
        ))
        #expect(ImageEditorCropDoubleClickCommitPolicy.shouldCommit(
            activeHandle: .move,
            clickCount: 2,
            viewTranslation: CGSize(width: 2, height: -2),
            hasConflictingModifiers: false
        ))
        #expect(!ImageEditorCropDoubleClickCommitPolicy.shouldCommit(
            activeHandle: .topLeft,
            clickCount: 2,
            viewTranslation: .zero,
            hasConflictingModifiers: false
        ))
        #expect(!ImageEditorCropDoubleClickCommitPolicy.shouldCommit(
            activeHandle: .move,
            clickCount: 1,
            viewTranslation: .zero,
            hasConflictingModifiers: false
        ))
        #expect(!ImageEditorCropDoubleClickCommitPolicy.shouldCommit(
            activeHandle: .move,
            clickCount: 2,
            viewTranslation: CGSize(width: 3, height: 0),
            hasConflictingModifiers: false
        ))
        #expect(!ImageEditorCropDoubleClickCommitPolicy.shouldCommit(
            activeHandle: .move,
            clickCount: 2,
            viewTranslation: .zero,
            hasConflictingModifiers: true
        ))

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("ImageEditorCropDoubleClickCommitPolicy.shouldCommit("))
        #expect(viewSource.contains("clickCount: currentEvent?.clickCount ?? 0"))
        #expect(viewSource.contains("if shouldCommitCrop, let pendingCropRect"))
        #expect(viewSource.contains("viewModel.crop(to: pendingCropRect)"))

        for (localizationID, expectedText) in [
            ("zh-Hans", "框内双击"),
            ("en", "double-click inside"),
            ("ja", "ダブルクリック")
        ] {
            let localization = try String(
                contentsOf: repositoryRoot
                    .appendingPathComponent("veilpic/\(localizationID).lproj/Localizable.strings"),
                encoding: .utf8
            )
            #expect(localization.contains(expectedText))
        }
    }

    @Test
    func cropRuleOfThirdsGuidesDivideThePreviewAndAreWiredToTheCanvas() throws {
        let guides = ImageEditorCropGeometry.ruleOfThirdsSegments(
            in: CGRect(x: 12, y: 18, width: 90, height: 60)
        )

        #expect(guides == [
            ImageEditorCropGuideSegment(
                start: CGPoint(x: 42, y: 18),
                end: CGPoint(x: 42, y: 78)
            ),
            ImageEditorCropGuideSegment(
                start: CGPoint(x: 72, y: 18),
                end: CGPoint(x: 72, y: 78)
            ),
            ImageEditorCropGuideSegment(
                start: CGPoint(x: 12, y: 38),
                end: CGPoint(x: 102, y: 38)
            ),
            ImageEditorCropGuideSegment(
                start: CGPoint(x: 12, y: 58),
                end: CGPoint(x: 102, y: 58)
            )
        ])
        #expect(ImageEditorCropGeometry.ruleOfThirdsSegments(in: .zero).isEmpty)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("ImageEditorCropGeometry.compositionGuideSegments"))
        #expect(source.contains("for segment in cropGuideSegments"))
    }

    @Test
    func cropCompositionGuideModesProvideUsefulGeometryAndPickerWiring() throws {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 80)
        let grid = ImageEditorCropGeometry.compositionGuideSegments(for: .grid, in: rect)
        #expect(grid.count == 6)
        assertEqual(grid[0].start, CGPoint(x: 35, y: 20))
        assertEqual(grid[2].end, CGPoint(x: 85, y: 100))
        assertEqual(grid[3].start, CGPoint(x: 10, y: 40))
        assertEqual(grid[5].end, CGPoint(x: 110, y: 80))

        let golden = ImageEditorCropGeometry.compositionGuideSegments(for: .goldenRatio, in: rect)
        #expect(golden.count == 4)
        assertEqual(golden[0].start, CGPoint(x: 48.196_601_125, y: 20))
        assertEqual(golden[1].end, CGPoint(x: 71.803_398_875, y: 100))
        #expect(ImageEditorCropGeometry.compositionGuideSegments(for: .none, in: rect).isEmpty)
        #expect(ImageEditorCropGuideKind.allCases == [.ruleOfThirds, .grid, .goldenRatio, .none])
        #expect(ImageEditorCropGuideKind.ruleOfThirds.next == .grid)
        #expect(ImageEditorCropGuideKind.grid.next == .goldenRatio)
        #expect(ImageEditorCropGuideKind.goldenRatio.next == .none)
        #expect(ImageEditorCropGuideKind.none.next == .ruleOfThirds)

        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "o",
            modifierFlags: [],
            activeTool: .crop,
            canCycleCropGuide: true
        ) == .cycleCropGuide)
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "o",
            modifierFlags: [],
            activeTool: .crop
        ) == nil)
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "o",
            modifierFlags: [],
            activeTool: .move,
            canCycleCropGuide: true
        ) == nil)
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "o",
            modifierFlags: [.command],
            activeTool: .crop,
            canCycleCropGuide: true
        ) == .openProject)
        #expect(ImageEditorKeyboardShortcutAction.cycleCropGuide.isBlockedByTextInput)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("selection: $cropGuideKind"))
        #expect(source.contains("ImageEditorCropGuideKind.allCases"))
        #expect(source.contains("image-editor-crop-guide-picker"))
        #expect(source.contains("canCycleCropGuide: pendingCropRect != nil"))
        #expect(source.contains("cropGuideKind = cropGuideKind.next"))
        #expect(source.contains("imageEditor.status.cropGuideChanged"))

        for localizationID in ["zh-Hans", "en", "ja"] {
            let localization = try String(
                contentsOf: repositoryRoot
                    .appendingPathComponent("veilpic/\(localizationID).lproj/Localizable.strings"),
                encoding: .utf8
            )
            for kind in ImageEditorCropGuideKind.allCases {
                #expect(localization.contains("\"\(kind.titleKey)\""))
            }
            #expect(localization.contains("\"imageEditor.cropGuide.title\""))
            #expect(localization.contains("\"imageEditor.cropGuide.help\""))
            #expect(localization.contains("\"imageEditor.status.cropGuideChanged\""))
        }
    }

    @Test
    func pendingCropXSwapsOrientationWithoutStealingTheColorShortcut() throws {
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "x",
            modifierFlags: [],
            activeTool: .crop,
            hasPendingCrop: true
        ) == .swapCropOrientation)
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "x",
            modifierFlags: [],
            activeTool: .crop,
            hasPendingCrop: false
        ) == nil)
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "x",
            modifierFlags: [],
            activeTool: .move,
            hasPendingCrop: true
        ) == nil)
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "x",
            modifierFlags: [.command],
            activeTool: .crop,
            hasPendingCrop: true
        ) == .cutSelectionClipboard)
        #expect(ImageEditorKeyboardShortcutAction.swapCropOrientation.isBlockedByTextInput)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("hasPendingCrop: pendingCropRect != nil"))
        #expect(source.contains("case .swapCropOrientation: swapPendingCropOrientation()"))
        #expect(source.contains("private func swapPendingCropOrientation()"))
        #expect(source.contains("Button {\n                            swapPendingCropOrientation()"))
        #expect(source.contains("ImageEditorCropGeometry.frameBySwappingCommittedDimensions"))

        for localizationID in ["zh-Hans", "en", "ja"] {
            let localization = try String(
                contentsOf: repositoryRoot
                    .appendingPathComponent("veilpic/\(localizationID).lproj/Localizable.strings"),
                encoding: .utf8
            )
            let swapHelp = try #require(localization.range(
                of: "\"imageEditor.cropBounds.swapHelp\""
            ))
            let swapHelpLine = localization[swapHelp.lowerBound...]
                .prefix { $0 != "\n" }
            #expect(swapHelpLine.contains("X"))
        }
    }

    @Test
    func pendingCropSlashTogglesTheCroppedOutsideAreaOnlyInCropContext() throws {
        for keyCode: UInt16? in [nil, 44] {
            #expect(ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: keyCode == nil ? "/" : nil,
                modifierFlags: [],
                keyCode: keyCode,
                activeTool: .crop,
                hasPendingCrop: true
            ) == .toggleCroppedAreaVisibility)
        }
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "/",
            modifierFlags: [],
            activeTool: .crop,
            hasPendingCrop: false
        ) == nil)
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "/",
            modifierFlags: [],
            activeTool: .move,
            hasPendingCrop: true
        ) == nil)
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "/",
            modifierFlags: [.shift],
            activeTool: .crop,
            hasPendingCrop: true
        ) == nil)
        #expect(ImageEditorKeyboardShortcutAction.toggleCroppedAreaVisibility.isBlockedByTextInput)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("@State private var showsCroppedArea = true"))
        #expect(source.contains("case .toggleCroppedAreaVisibility: showsCroppedArea.toggle()"))
        #expect(source.contains("showsCroppedArea\n                    ? Color.black.opacity(cropShieldOpacity)"))
        #expect(source.contains(": Color(nsColor: ImageEditorTheme.window)"))
        #expect(source.contains("image-editor-crop-outside-area-toggle"))
        #expect(source.contains(".accessibilityLabel(L10n.text(\"imageEditor.cropBounds.croppedAreaHelp\"))"))

        for localizationID in ["zh-Hans", "en", "ja"] {
            let localization = try String(
                contentsOf: repositoryRoot
                    .appendingPathComponent("veilpic/\(localizationID).lproj/Localizable.strings"),
                encoding: .utf8
            )
            let help = try #require(localization.range(
                of: "\"imageEditor.cropBounds.croppedAreaHelp\""
            ))
            let helpLine = localization[help.lowerBound...]
                .prefix { $0 != "\n" }
            #expect(helpLine.contains("/"))
        }
    }

    @Test
    func cropShieldOpacityPresetsRemainUsableAcrossCroppedAreaVisibility() throws {
        #expect(ImageEditorCropShieldOpacityPreset.allCases == [.light, .standard, .strong])
        #expect(ImageEditorCropShieldOpacityPreset.light.opacity == 0.25)
        #expect(ImageEditorCropShieldOpacityPreset.standard.opacity == 0.50)
        #expect(ImageEditorCropShieldOpacityPreset.strong.opacity == 0.75)
        #expect(
            Set(ImageEditorCropShieldOpacityPreset.allCases.map(\.accessibilityIdentifier)).count
                == ImageEditorCropShieldOpacityPreset.allCases.count
        )

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("@State private var cropShieldOpacity = ImageEditorCropShieldOpacityPreset.standard.opacity"))
        #expect(source.contains("ImageEditorCropShieldOpacityPreset.allCases"))
        #expect(source.contains("cropShieldOpacity = preset.opacity"))
        #expect(source.contains("Color.black.opacity(cropShieldOpacity)"))
        #expect(source.contains(".disabled(!showsCroppedArea)"))
        #expect(source.contains("image-editor-crop-shield-opacity-menu"))

        for localizationID in ["zh-Hans", "en", "ja"] {
            let localization = try String(
                contentsOf: repositoryRoot
                    .appendingPathComponent("veilpic/\(localizationID).lproj/Localizable.strings"),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.cropShield.opacityHelp\""))
            for preset in ImageEditorCropShieldOpacityPreset.allCases {
                #expect(localization.contains("\"\(preset.titleKey)\""))
            }
        }
    }

    @Test
    func pendingCropUsesClassicConfirmAndCancelKeysBeforeOtherCanvasActions() throws {
        for keyCode: UInt16 in [36, 76] {
            #expect(ImageEditorPendingCropKeyPolicy.matchesConfirm(
                keyCode: keyCode,
                modifierFlags: []
            ))
            #expect(!ImageEditorPendingCropKeyPolicy.matchesConfirm(
                keyCode: keyCode,
                modifierFlags: [.command]
            ))
        }
        #expect(ImageEditorPendingCropKeyPolicy.matchesCancel(
            keyCode: 53,
            modifierFlags: []
        ))
        #expect(!ImageEditorPendingCropKeyPolicy.matchesCancel(
            keyCode: 53,
            modifierFlags: [.shift]
        ))
        #expect(!ImageEditorPendingCropKeyPolicy.matchesCancel(
            keyCode: 36,
            modifierFlags: []
        ))

        var cropCancelCount = 0
        var fallbackCancelCount = 0
        #expect(ImageEditorPendingCropCancelDispatcher.handle(
            cancelPendingCrop: {
                cropCancelCount += 1
                return true
            },
            cancelFallback: {
                fallbackCancelCount += 1
                return true
            }
        ))
        #expect(cropCancelCount == 1)
        #expect(fallbackCancelCount == 0)
        #expect(ImageEditorPendingCropCancelDispatcher.handle(
            cancelPendingCrop: {
                cropCancelCount += 1
                return false
            },
            cancelFallback: {
                fallbackCancelCount += 1
                return true
            }
        ))
        #expect(cropCancelCount == 2)
        #expect(fallbackCancelCount == 1)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("confirmPendingCrop: {"))
        #expect(source.contains("cancelPendingCrop: {"))
        #expect(source.contains("viewModel.crop(to: pendingCropRect)"))
        #expect(source.contains("ImageEditorPendingCropCancelDispatcher.handle"))
        let cropConfirmIndex = try #require(source.range(of: "confirmPendingCrop()"))
        let penConfirmIndex = try #require(source.range(of: "finishPendingPenPath()"))
        #expect(cropConfirmIndex.lowerBound < penConfirmIndex.lowerBound)

        for localizationID in ["zh-Hans", "en", "ja"] {
            let localization = try String(
                contentsOf: repositoryRoot
                    .appendingPathComponent("veilpic/\(localizationID).lproj/Localizable.strings"),
                encoding: .utf8
            )
            #expect(localization.contains("\"imageEditor.action.cropConfirm\""))
            #expect(localization.contains("\"imageEditor.action.cropCancel\""))
        }
    }

    @Test
    func pendingCropDeleteResetsBeforeSelectedObjectDeletion() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let deleteFunction = try #require(source.range(
            of: "func deleteSelectedObjectFromKeyboard("
        ))
        let cropReset = try #require(source.range(
            of: "if resetPendingCropToCanvas()",
            range: deleteFunction.lowerBound..<source.endIndex
        ))
        let layerDelete = try #require(source.range(
            of: "viewModel.deleteSelectedLayerFromKeyboardIfPossible()",
            range: deleteFunction.lowerBound..<source.endIndex
        ))
        #expect(cropReset.lowerBound < layerDelete.lowerBound)
        #expect(source.contains("return finishDispatch(true)"))
        #expect(source.contains("private func resetPendingCropToCanvas() -> Bool"))
        #expect(source.contains("pendingCropRect = ImageEditorCropGeometry.fullCanvasFrame"))
        #expect(source.contains("endPendingCropInteraction()"))
        #expect(source.contains("Button {\n                        resetPendingCropToCanvas()"))

        for localizationID in ["zh-Hans", "en", "ja"] {
            let localization = try String(
                contentsOf: repositoryRoot
                    .appendingPathComponent("veilpic/\(localizationID).lproj/Localizable.strings"),
                encoding: .utf8
            )
            let resetHelp = try #require(localization.range(
                of: "\"imageEditor.cropBounds.resetHelp\""
            ))
            let resetHelpLine = localization[resetHelp.lowerBound...]
                .prefix { $0 != "\n" }
            #expect(resetHelpLine.contains("Delete"))
        }
    }

    @Test
    func pendingCropArrowNudgeMovesInsideCanvasBeforeFallingBackToSelection() throws {
        let original = CGRect(x: 10, y: 12, width: 40, height: 20)
        let canvasSize = CGSize(width: 100, height: 80)
        #expect(ImageEditorCropGeometry.adjustedFrame(
            from: original,
            handle: .move,
            delta: try #require(ImageEditorArrowNudge.delta(
                for: 123,
                modifierFlags: [.option]
            )),
            canvasSize: canvasSize
        ) == CGRect(x: 5, y: 12, width: 40, height: 20))
        #expect(ImageEditorCropGeometry.adjustedFrame(
            from: original,
            handle: .move,
            delta: try #require(ImageEditorArrowNudge.delta(
                for: 126,
                modifierFlags: [.shift]
            )),
            canvasSize: canvasSize
        ) == CGRect(x: 10, y: 2, width: 40, height: 20))
        #expect(ImageEditorCropGeometry.adjustedFrame(
            from: CGRect(x: 0, y: 0, width: 40, height: 20),
            handle: .move,
            delta: CGSize(width: -10, height: -10),
            canvasSize: canvasSize
        ) == CGRect(x: 0, y: 0, width: 40, height: 20))

        var cropDeltas: [CGSize] = []
        var fallbackDeltas: [CGSize] = []
        ImageEditorPendingCropNudgeDispatcher.perform(
            delta: CGSize(width: 1, height: 0),
            nudgePendingCrop: {
                cropDeltas.append($0)
                return true
            },
            nudgeFallback: { fallbackDeltas.append($0) }
        )
        #expect(cropDeltas == [CGSize(width: 1, height: 0)])
        #expect(fallbackDeltas.isEmpty)
        ImageEditorPendingCropNudgeDispatcher.perform(
            delta: CGSize(width: 0, height: 5),
            nudgePendingCrop: {
                cropDeltas.append($0)
                return false
            },
            nudgeFallback: { fallbackDeltas.append($0) }
        )
        #expect(cropDeltas.last == CGSize(width: 0, height: 5))
        #expect(fallbackDeltas == [CGSize(width: 0, height: 5)])

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("nudgePendingCrop: { delta in"))
        #expect(source.contains("handle: .move"))
        #expect(source.contains("ImageEditorPendingCropNudgeDispatcher.perform"))
    }

    @Test
    func cropShieldDimsOnlyTheCanvasAreaOutsideThePreview() throws {
        let canvas = CGRect(x: 10, y: 20, width: 100, height: 80)
        #expect(ImageEditorCropGeometry.shieldRects(
            in: canvas,
            excluding: CGRect(x: 30, y: 35, width: 60, height: 50)
        ) == [
            CGRect(x: 10, y: 20, width: 100, height: 15),
            CGRect(x: 10, y: 85, width: 100, height: 15),
            CGRect(x: 10, y: 35, width: 20, height: 50),
            CGRect(x: 90, y: 35, width: 20, height: 50)
        ])
        #expect(ImageEditorCropGeometry.shieldRects(in: canvas, excluding: canvas).isEmpty)
        #expect(ImageEditorCropGeometry.shieldRects(
            in: canvas,
            excluding: CGRect(x: -200, y: -200, width: 10, height: 10)
        ) == [canvas])

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("ImageEditorCropGeometry.shieldRects"))
        #expect(source.contains("for shieldRect in cropShieldRects"))
        #expect(source.contains("Color.black.opacity(cropShieldOpacity)"))
    }

    private func assertEqual(
        _ actual: CGRect,
        _ expected: CGRect,
        accuracy: CGFloat = 0.001
    ) {
        #expect(abs(actual.origin.x - expected.origin.x) < accuracy)
        #expect(abs(actual.origin.y - expected.origin.y) < accuracy)
        #expect(abs(actual.width - expected.width) < accuracy)
        #expect(abs(actual.height - expected.height) < accuracy)
    }

    private func assertEqual(
        _ actual: CGPoint,
        _ expected: CGPoint,
        accuracy: CGFloat = 0.001
    ) {
        #expect(abs(actual.x - expected.x) < accuracy)
        #expect(abs(actual.y - expected.y) < accuracy)
    }
}
