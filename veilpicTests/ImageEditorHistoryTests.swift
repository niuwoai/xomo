//
//  ImageEditorHistoryTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorHistoryTests {
    @Test func onePhysicalCommandTTogglesTransformControlsOnlyOnce() {
        ImageEditorTransformControlsCommandDispatchGate.reset()
        defer { ImageEditorTransformControlsCommandDispatchGate.reset() }

        let image = testImage(color: .systemGreen, size: NSSize(width: 32, height: 24))
        let viewModel = ImageEditorViewModel(sourceName: "transform-controls.png", image: image) { _ in }
        let historyCount = viewModel.document.history.count
        let event = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 47,
            eventNumber: 991,
            timestamp: 99.1,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 17
        )

        for _ in 0..<2 {
            guard ImageEditorTransformControlsCommandDispatchGate.shouldDispatch(
                event: event
            ) else { continue }
            viewModel.toggleTransformControlsVisible()
        }

        #expect(!viewModel.document.areTransformControlsVisible)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(
            viewModel.document.history.last?.title
                == L10n.text("imageEditor.history.transformControlsVisibility")
        )
    }

    @Test func transformControlsMouseBoundariesRemainIndependentWithoutAKeyEvent() {
        ImageEditorTransformControlsCommandDispatchGate.reset()
        defer { ImageEditorTransformControlsCommandDispatchGate.reset() }

        #expect(ImageEditorTransformControlsCommandDispatchGate.shouldDispatch(event: nil))
        #expect(ImageEditorTransformControlsCommandDispatchGate.shouldDispatch(event: nil))
    }

    @Test func onePhysicalLayerViaCutShortcutCreatesOnlyOneLayer() {
        ImageEditorLayerCutCommandDispatchGate.reset()
        defer { ImageEditorLayerCutCommandDispatchGate.reset() }

        let canvasSize = NSSize(width: 48, height: 36)
        let image = testImage(color: .systemPink, size: canvasSize)
        let viewModel = ImageEditorViewModel(
            sourceName: "layer-via-cut.png",
            image: image
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            image,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.createRectSelection(
            from: CGPoint(x: 8, y: 6),
            to: CGPoint(x: 28, y: 22)
        )
        #expect(viewModel.canCutSelectionToNewLayer)
        let layerCount = viewModel.document.layers.count
        let historyCount = viewModel.document.history.count
        let event = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 53,
            eventNumber: 1001,
            timestamp: 100.1,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 38
        )

        for _ in 0..<2 {
            guard ImageEditorLayerCutCommandDispatchGate.shouldDispatch(
                event: event
            ) else { continue }
            viewModel.cutSelectionToNewLayer()
        }

        #expect(viewModel.document.layers.count == layerCount + 1)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(
            viewModel.document.history.last?.title
                == L10n.text("imageEditor.history.selectionCutLayer")
        )
    }

    @Test func layerViaCutMouseBoundariesRemainIndependentWithoutAKeyEvent() {
        ImageEditorLayerCutCommandDispatchGate.reset()
        defer { ImageEditorLayerCutCommandDispatchGate.reset() }

        #expect(ImageEditorLayerCutCommandDispatchGate.shouldDispatch(event: nil))
        #expect(ImageEditorLayerCutCommandDispatchGate.shouldDispatch(event: nil))
    }

    @Test func onePhysicalFileShortcutDispatchesEachActionOnlyOnce() {
        let event = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 43,
            eventNumber: 981,
            timestamp: 98.1,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 1
        )

        for action in ImageEditorFileCommandAction.allCases {
            ImageEditorFileCommandDispatchGate.reset()
            var dispatchCount = 0
            for _ in 0..<2 where ImageEditorFileCommandDispatchGate.shouldDispatch(
                action,
                event: event
            ) {
                dispatchCount += 1
            }
            #expect(dispatchCount == 1)
        }

        ImageEditorFileCommandDispatchGate.reset()
        #expect(ImageEditorFileCommandDispatchGate.shouldDispatch(.createCanvas, event: event))
        #expect(ImageEditorFileCommandDispatchGate.shouldDispatch(.openProject, event: event))
    }

    @Test func fileMouseAndQuickActionBoundariesRemainIndependentWithoutAKeyEvent() {
        ImageEditorFileCommandDispatchGate.reset()
        defer { ImageEditorFileCommandDispatchGate.reset() }

        for action in ImageEditorFileCommandAction.allCases {
            #expect(ImageEditorFileCommandDispatchGate.shouldDispatch(action, event: nil))
            #expect(ImageEditorFileCommandDispatchGate.shouldDispatch(action, event: nil))
        }
    }

    @Test func clipboardMouseMenuBoundariesRemainIndependentWithoutAKeyEvent() {
        ImageEditorClipboardCommandDispatchGate.reset()
        defer { ImageEditorClipboardCommandDispatchGate.reset() }

        for action in ImageEditorClipboardCommandAction.allCases {
            #expect(ImageEditorClipboardCommandDispatchGate.shouldDispatch(action, event: nil))
            #expect(ImageEditorClipboardCommandDispatchGate.shouldDispatch(action, event: nil))
        }
    }

    @Test func onePhysicalCommandJCreatesOnlyOneLayerCopy() {
        ImageEditorLayerDuplicateCommandDispatchGate.reset()
        defer { ImageEditorLayerDuplicateCommandDispatchGate.reset() }

        let image = testImage(color: .systemBlue, size: NSSize(width: 24, height: 18))
        let viewModel = ImageEditorViewModel(sourceName: "duplicate.png", image: image) { _ in }
        viewModel.convertBackgroundToLayer()
        let layerCount = viewModel.document.layers.count
        let historyCount = viewModel.document.history.count
        let event = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 37,
            eventNumber: 961,
            timestamp: 96.1,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 38
        )

        for _ in 0..<2 {
            guard ImageEditorLayerDuplicateCommandDispatchGate.shouldDispatch(
                event: event
            ) else { continue }
            viewModel.duplicateSelectionOrSelectedLayer()
        }

        #expect(viewModel.document.layers.count == layerCount + 1)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(
            viewModel.document.history.last?.title
                == L10n.text("imageEditor.history.layerDuplicate")
        )
    }

    @Test func layerDuplicateMouseMenuBoundariesRemainIndependentWithoutAKeyEvent() {
        ImageEditorLayerDuplicateCommandDispatchGate.reset()
        defer { ImageEditorLayerDuplicateCommandDispatchGate.reset() }

        #expect(ImageEditorLayerDuplicateCommandDispatchGate.shouldDispatch(event: nil))
        #expect(ImageEditorLayerDuplicateCommandDispatchGate.shouldDispatch(event: nil))
    }

    @Test func onePhysicalRepeatLastFilterShortcutCommitsOnlyOneFilter() throws {
        ImageEditorLastFilterCommandDispatchGate.reset()
        defer { ImageEditorLastFilterCommandDispatchGate.reset() }

        let viewModel = try makePixelShortcutViewModel()
        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.35
        viewModel.filterGaussianBlurRadius = 1
        viewModel.applySelectedFilter()
        let original = try viewModel.projectData()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        let event = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 31,
            eventNumber: 951,
            timestamp: 95.1,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 3
        )

        for _ in 0..<2 {
            guard ImageEditorLastFilterCommandDispatchGate.shouldDispatch(
                event: event
            ) else { continue }
            viewModel.applyLastFilter()
        }

        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(
            viewModel.document.history.last?.title
                == L10n.format(
                    "imageEditor.history.filter",
                    ImageEditorFilter.gaussianBlur.title
                )
        )
        let edited = try viewModel.projectData()
        #expect(edited != original)
        viewModel.undo()
        #expect(try viewModel.projectData() == original)
        viewModel.redo()
        #expect(try viewModel.projectData() == edited)
    }

    @Test func repeatLastFilterMouseMenuBoundariesRemainIndependentWithoutAKeyEvent() {
        ImageEditorLastFilterCommandDispatchGate.reset()
        defer { ImageEditorLastFilterCommandDispatchGate.reset() }

        #expect(ImageEditorLastFilterCommandDispatchGate.shouldDispatch(event: nil))
        #expect(ImageEditorLastFilterCommandDispatchGate.shouldDispatch(event: nil))
    }

    @Test func onePhysicalPixelInvertShortcutCommitsOnlyOneCorrection() throws {
        ImageEditorPixelCorrectionCommandDispatchGate.reset()
        defer { ImageEditorPixelCorrectionCommandDispatchGate.reset() }

        let viewModel = try makePixelShortcutViewModel()
        let original = try viewModel.projectData()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        let event = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 29,
            eventNumber: 941,
            timestamp: 94.1,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 34
        )

        for _ in 0..<2 {
            guard ImageEditorPixelCorrectionCommandDispatchGate.shouldDispatch(
                .invert,
                event: event
            ) else { continue }
            #expect(viewModel.invertCurrentEditingTarget())
        }

        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.invert"))
        let edited = try viewModel.projectData()
        #expect(edited != original)
        viewModel.undo()
        #expect(try viewModel.projectData() == original)
        viewModel.redo()
        #expect(try viewModel.projectData() == edited)
    }

    @Test func pixelCorrectionMouseMenuBoundariesRemainIndependentWithoutAKeyEvent() {
        ImageEditorPixelCorrectionCommandDispatchGate.reset()
        defer { ImageEditorPixelCorrectionCommandDispatchGate.reset() }

        for action in ImageEditorPixelCorrectionCommandAction.allCases {
            #expect(ImageEditorPixelCorrectionCommandDispatchGate.shouldDispatch(action, event: nil))
            #expect(ImageEditorPixelCorrectionCommandDispatchGate.shouldDispatch(action, event: nil))
        }
    }

    @Test func onePhysicalSelectionInvertShortcutCommitsOnlyOneInversion() throws {
        ImageEditorSelectionCommandDispatchGate.reset()
        defer { ImageEditorSelectionCommandDispatchGate.reset() }

        let canvas = try #require(NSImage.rendered(size: NSSize(width: 40, height: 30)) { rect in
            NSColor.white.setFill()
            rect.fill()
        })
        let viewModel = ImageEditorViewModel(sourceName: "selection.png", image: canvas) { _ in }
        let originalSelection = ImageEditorSelection.rectangle(
            CGRect(x: 3, y: 4, width: 11, height: 9)
        )
        viewModel.document.selection = originalSelection
        let historyCount = viewModel.document.history.count
        let event = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 23,
            eventNumber: 931,
            timestamp: 93.1,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 34
        )

        for _ in 0..<2 {
            guard ImageEditorSelectionCommandDispatchGate.shouldDispatch(
                .invert,
                event: event
            ) else { continue }
            viewModel.invertSelection()
        }

        let selection = try #require(viewModel.document.selection)
        #expect(selection.bounds == originalSelection.bounds)
        #expect(selection.isInverted)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(
            viewModel.document.history.last?.title
                == L10n.text("imageEditor.history.selectionInverted")
        )
    }

    @Test func onePhysicalSelectionFeatherShortcutAppliesOnlyOneRadiusPass() throws {
        ImageEditorSelectionCommandDispatchGate.reset()
        defer { ImageEditorSelectionCommandDispatchGate.reset() }

        let canvasSize = NSSize(width: 40, height: 30)
        let canvas = testImage(color: .white, size: canvasSize)
        let originalSelection = ImageEditorSelection.rectangle(
            CGRect(x: 10, y: 8, width: 10, height: 10)
        )
        let expected = ImageEditorViewModel(
            sourceName: "expected-feather.png",
            image: canvas
        ) { _ in }
        expected.document.selection = originalSelection
        expected.selectionModifyAmount = 3
        expected.featherSelection()

        let viewModel = ImageEditorViewModel(
            sourceName: "shortcut-feather.png",
            image: canvas
        ) { _ in }
        viewModel.document.selection = originalSelection
        viewModel.selectionModifyAmount = 3
        let historyCount = viewModel.document.history.count
        let event = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 31,
            eventNumber: 951,
            timestamp: 95.1,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 2
        )

        for _ in 0..<2 {
            guard ImageEditorSelectionCommandDispatchGate.shouldDispatch(
                .feather,
                event: event
            ) else { continue }
            viewModel.featherSelection()
        }

        #expect(viewModel.document.selection == expected.document.selection)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(
            viewModel.document.history.last?.title
                == L10n.text("imageEditor.history.selectionFeather")
        )
    }

    @Test func selectionMouseMenuBoundariesRemainIndependentWithoutAKeyEvent() {
        ImageEditorSelectionCommandDispatchGate.reset()
        defer { ImageEditorSelectionCommandDispatchGate.reset() }

        for action in ImageEditorSelectionCommandAction.allCases {
            #expect(ImageEditorSelectionCommandDispatchGate.shouldDispatch(action, event: nil))
            #expect(ImageEditorSelectionCommandDispatchGate.shouldDispatch(action, event: nil))
        }
    }

    @Test func onePhysicalForegroundFillShortcutAppliesOpacityOnlyOnce() throws {
        ImageEditorSelectionFillCommandDispatchGate.reset()
        defer { ImageEditorSelectionFillCommandDispatchGate.reset() }

        let canvasSize = NSSize(width: 24, height: 18)
        let image = testImage(color: .clear, size: canvasSize)
        let expected = ImageEditorViewModel(
            sourceName: "expected-fill.png",
            image: image
        ) { _ in }
        expected.selectAll()
        expected.foregroundColor = .systemRed
        expected.opacity = 0.5
        expected.fillSelection()
        let expectedPixels = try #require(
            expected.document.selectedLayer?.image.qingtuPNGData()
        )

        let viewModel = ImageEditorViewModel(
            sourceName: "shortcut-fill.png",
            image: image
        ) { _ in }
        viewModel.selectAll()
        viewModel.foregroundColor = .systemRed
        viewModel.opacity = 0.5
        let historyCount = viewModel.document.history.count
        let event = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 59,
            eventNumber: 1011,
            timestamp: 101.1,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 51
        )

        for _ in 0..<2 {
            guard ImageEditorSelectionFillCommandDispatchGate.shouldDispatch(
                .foreground,
                event: event
            ) else { continue }
            viewModel.fillSelection()
        }

        #expect(try #require(viewModel.document.selectedLayer?.image.qingtuPNGData()) == expectedPixels)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(
            viewModel.document.history.last?.title
                == L10n.text("imageEditor.history.selectionFill")
        )
    }

    @Test func selectionFillMouseBoundariesRemainIndependentWithoutAKeyEvent() {
        ImageEditorSelectionFillCommandDispatchGate.reset()
        defer { ImageEditorSelectionFillCommandDispatchGate.reset() }

        for action in ImageEditorSelectionFillCommandAction.allCases {
            #expect(ImageEditorSelectionFillCommandDispatchGate.shouldDispatch(action, event: nil))
            #expect(ImageEditorSelectionFillCommandDispatchGate.shouldDispatch(action, event: nil))
        }
    }

    @Test func onePhysicalImageGeometryShortcutKeepsTheSuccessfulResizeStatus() {
        ImageEditorImageGeometryCommandDispatchGate.reset()
        defer { ImageEditorImageGeometryCommandDispatchGate.reset() }

        let cases: [(
            action: ImageEditorImageGeometryCommandAction,
            targetSize: CGSize,
            historyKey: String
        )] = [
            (.resizeImage, CGSize(width: 84, height: 66), "imageEditor.history.imageResize"),
            (.resizeCanvas, CGSize(width: 92, height: 70), "imageEditor.history.canvasResize"),
        ]

        for (index, testCase) in cases.enumerated() {
            ImageEditorImageGeometryCommandDispatchGate.reset()
            let viewModel = ImageEditorViewModel(
                sourceName: "geometry-\(index).png",
                image: testImage(color: .systemBlue, size: NSSize(width: 64, height: 48))
            ) { _ in }
            viewModel.targetImageWidth = Double(testCase.targetSize.width)
            viewModel.targetImageHeight = Double(testCase.targetSize.height)
            viewModel.targetCanvasWidth = Double(testCase.targetSize.width)
            viewModel.targetCanvasHeight = Double(testCase.targetSize.height)
            let historyCount = viewModel.document.history.count
            let event = ImageEditorKeyboardShortcutEventSignature(
                windowNumber: 61,
                eventNumber: 1030 + index,
                timestamp: 103 + Double(index) / 10,
                typeRawValue: NSEvent.EventType.keyDown.rawValue,
                keyCode: testCase.action == .resizeImage ? 34 : 8
            )

            for _ in 0..<2 {
                guard ImageEditorImageGeometryCommandDispatchGate.shouldDispatch(
                    testCase.action,
                    event: event
                ) else { continue }
                switch testCase.action {
                case .resizeImage: viewModel.resizeImageToControlSize()
                case .resizeCanvas: viewModel.resizeCanvasToControlSize()
                }
            }

            #expect(viewModel.document.canvasSize == testCase.targetSize)
            #expect(viewModel.document.history.count == historyCount + 1)
            #expect(viewModel.document.history.last?.title == L10n.text(testCase.historyKey))
            #expect(viewModel.statusText != L10n.text("imageEditor.status.resizeInvalid"))
        }
    }

    @Test func imageGeometryMouseBoundariesRemainIndependentWithoutAKeyEvent() {
        ImageEditorImageGeometryCommandDispatchGate.reset()
        defer { ImageEditorImageGeometryCommandDispatchGate.reset() }

        for action in ImageEditorImageGeometryCommandAction.allCases {
            #expect(ImageEditorImageGeometryCommandDispatchGate.shouldDispatch(action, event: nil))
            #expect(ImageEditorImageGeometryCommandDispatchGate.shouldDispatch(action, event: nil))
        }
    }

    @Test func onePhysicalArrowShortcutNudgesOnlyOneDistanceStep() throws {
        ImageEditorNudgeCommandDispatchGate.reset()
        defer { ImageEditorNudgeCommandDispatchGate.reset() }

        let canvas = try #require(NSImage.rendered(size: NSSize(width: 64, height: 64)) { rect in
            NSColor.white.setFill()
            rect.fill()
        })
        let importedImage = try #require(NSImage.rendered(size: NSSize(width: 16, height: 16)) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
        })
        let viewModel = ImageEditorViewModel(sourceName: "nudge.png", image: canvas) { _ in }
        #expect(viewModel.importImageLayer(
            importedImage,
            sourceName: "object.png"
        ))
        let selectedID = try #require(viewModel.document.selectedLayerID)
        let initialFrame = try #require(
            viewModel.document.layers.first(where: { $0.id == selectedID })?.frame
        )
        let historyCount = viewModel.document.history.count
        let deltas = [
            CGSize(width: 1, height: 0),
            CGSize(width: 5, height: 0),
            CGSize(width: 10, height: 0)
        ]

        for (index, delta) in deltas.enumerated() {
            let event = ImageEditorKeyboardShortcutEventSignature(
                windowNumber: 19,
                eventNumber: 920 + index,
                timestamp: 92 + Double(index) / 10,
                typeRawValue: NSEvent.EventType.keyDown.rawValue,
                keyCode: 124
            )
            for _ in 0..<2 {
                guard ImageEditorNudgeCommandDispatchGate.shouldDispatch(
                    delta,
                    event: event
                ) else { continue }
                viewModel.nudgeSelectionOrSelectedLayer(by: delta)
            }
        }

        let finalFrame = try #require(
            viewModel.document.layers.first(where: { $0.id == selectedID })?.frame
        )
        #expect(finalFrame.origin.x == initialFrame.origin.x + 16)
        #expect(finalFrame.origin.y == initialFrame.origin.y)
        #expect(viewModel.document.history.count == historyCount + 3)
    }

    @Test func nudgeFallbackBoundariesRemainIndependentWithoutAKeyEvent() {
        ImageEditorNudgeCommandDispatchGate.reset()
        defer { ImageEditorNudgeCommandDispatchGate.reset() }

        let delta = CGSize(width: 1, height: 0)
        #expect(ImageEditorNudgeCommandDispatchGate.shouldDispatch(delta, event: nil))
        #expect(ImageEditorNudgeCommandDispatchGate.shouldDispatch(delta, event: nil))
    }

    @Test func onePhysicalZoomShortcutAdvancesOnlyOneZoomStep() {
        ImageEditorZoomCommandDispatchGate.reset()
        defer { ImageEditorZoomCommandDispatchGate.reset() }

        let image = NSImage(size: NSSize(width: 32, height: 24))
        let viewModel = ImageEditorViewModel(sourceName: "zoom.png", image: image) { _ in }
        let firstEvent = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 17,
            eventNumber: 911,
            timestamp: 91,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 24
        )
        let secondEvent = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 17,
            eventNumber: 912,
            timestamp: 91.2,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 24
        )
        let initialZoom = viewModel.zoom

        func dispatch(
            _ action: ImageEditorZoomCommandAction,
            event: ImageEditorKeyboardShortcutEventSignature?
        ) {
            guard ImageEditorZoomCommandDispatchGate.shouldDispatch(
                action,
                event: event
            ) else { return }
            switch action {
            case .zoomIn: viewModel.zoomIn()
            case .zoomOut: viewModel.zoomOut()
            case .actualPixels: viewModel.zoomActualPixels()
            case .fitOnScreen: viewModel.fitZoom()
            }
        }

        dispatch(.zoomIn, event: firstEvent)
        dispatch(.zoomIn, event: firstEvent)
        #expect(abs(viewModel.zoom - initialZoom * 1.2) < 0.000_001)

        dispatch(.zoomIn, event: secondEvent)
        #expect(abs(viewModel.zoom - initialZoom * 1.44) < 0.000_001)

        ImageEditorZoomCommandDispatchGate.reset()
        viewModel.setZoom(initialZoom)
        dispatch(.zoomOut, event: firstEvent)
        dispatch(.zoomOut, event: firstEvent)
        #expect(abs(viewModel.zoom - initialZoom / 1.2) < 0.000_001)
    }

    @Test func zoomMouseMenuBoundariesAndActionsRemainIndependent() {
        ImageEditorZoomCommandDispatchGate.reset()
        defer { ImageEditorZoomCommandDispatchGate.reset() }

        let event = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 17,
            eventNumber: 913,
            timestamp: 91.4,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 24
        )
        for action in [
            ImageEditorZoomCommandAction.zoomIn,
            .zoomOut,
            .actualPixels,
            .fitOnScreen
        ] {
            ImageEditorZoomCommandDispatchGate.reset()
            #expect(ImageEditorZoomCommandDispatchGate.shouldDispatch(action, event: event))
            #expect(!ImageEditorZoomCommandDispatchGate.shouldDispatch(action, event: event))
            #expect(ImageEditorZoomCommandDispatchGate.shouldDispatch(action, event: nil))
            #expect(ImageEditorZoomCommandDispatchGate.shouldDispatch(action, event: nil))
        }
    }

    @Test func onePhysicalCanvasAidShortcutTogglesOnlyOneStateTransition() {
        ImageEditorCanvasAidCommandDispatchGate.reset()
        defer { ImageEditorCanvasAidCommandDispatchGate.reset() }

        let image = NSImage(size: NSSize(width: 32, height: 24))
        let viewModel = ImageEditorViewModel(sourceName: "canvas-aids.png", image: image) { _ in }
        let event = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 17,
            eventNumber: 901,
            timestamp: 90,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 15
        )
        let nextEvent = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 17,
            eventNumber: 902,
            timestamp: 90.2,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 15
        )
        let historyCount = viewModel.document.history.count

        func dispatch(_ action: ImageEditorCanvasAidCommandAction, event: ImageEditorKeyboardShortcutEventSignature?) {
            guard ImageEditorCanvasAidCommandDispatchGate.shouldDispatch(
                action,
                event: event
            ) else { return }
            switch action {
            case .rulers: viewModel.toggleRulersVisible()
            case .guides: viewModel.toggleGuidesVisible()
            case .guideSnapping: viewModel.toggleGuideSnapping()
            case .guidesLocked: viewModel.toggleGuidesLocked()
            case .grid: viewModel.toggleGridVisible()
            }
        }

        for action in [
            ImageEditorCanvasAidCommandAction.rulers,
            .guides,
            .guideSnapping,
            .guidesLocked,
            .grid
        ] {
            ImageEditorCanvasAidCommandDispatchGate.reset()
            dispatch(action, event: event)
            dispatch(action, event: event)
        }

        #expect(!viewModel.document.areRulersVisible)
        #expect(!viewModel.document.areGuidesVisible)
        #expect(!viewModel.document.isGuideSnappingEnabled)
        #expect(viewModel.document.areGuidesLocked)
        #expect(viewModel.document.isGridVisible)
        #expect(viewModel.document.history.count == historyCount + 5)

        dispatch(.grid, event: nextEvent)
        #expect(!viewModel.document.isGridVisible)
        #expect(viewModel.document.history.count == historyCount + 6)
    }

    @Test func canvasAidMouseMenuBoundariesRemainIndependent() {
        ImageEditorCanvasAidCommandDispatchGate.reset()
        defer { ImageEditorCanvasAidCommandDispatchGate.reset() }

        for action in [
            ImageEditorCanvasAidCommandAction.rulers,
            .guides,
            .guideSnapping,
            .guidesLocked,
            .grid
        ] {
            #expect(ImageEditorCanvasAidCommandDispatchGate.shouldDispatch(action, event: nil))
            #expect(ImageEditorCanvasAidCommandDispatchGate.shouldDispatch(action, event: nil))
        }
    }

    @Test func onePhysicalHistoryShortcutAdvancesOnlyOneUndoStep() {
        ImageEditorHistoryCommandDispatchGate.reset()
        defer { ImageEditorHistoryCommandDispatchGate.reset() }

        let image = NSImage(size: NSSize(width: 32, height: 24))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        viewModel.addLayer()
        viewModel.addLayer()
        viewModel.addLayer()
        let initialLayerCount = viewModel.document.layers.count
        let firstEvent = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 7,
            eventNumber: 101,
            timestamp: 30,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 6
        )
        let secondEvent = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 7,
            eventNumber: 102,
            timestamp: 30.2,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 6
        )

        func dispatchUndo(event: ImageEditorKeyboardShortcutEventSignature?) {
            guard ImageEditorHistoryCommandDispatchGate.shouldDispatch(
                event: event
            ) else { return }
            viewModel.undo()
        }

        dispatchUndo(event: firstEvent)
        dispatchUndo(event: firstEvent)
        #expect(viewModel.document.layers.count == initialLayerCount - 1)

        dispatchUndo(event: secondEvent)
        #expect(viewModel.document.layers.count == initialLayerCount - 2)

        dispatchUndo(event: nil)
        #expect(viewModel.document.layers.count == initialLayerCount - 3)
    }

    @Test func everyHistoryRouteSharesOnePhysicalEventBoundary() {
        ImageEditorHistoryCommandDispatchGate.reset()
        defer { ImageEditorHistoryCommandDispatchGate.reset() }
        let event = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 9,
            eventNumber: 203,
            timestamp: 44,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 6
        )

        #expect(ImageEditorHistoryCommandDispatchGate.shouldDispatch(event: event))
        #expect(!ImageEditorHistoryCommandDispatchGate.shouldDispatch(event: event))
        #expect(ImageEditorHistoryCommandDispatchGate.shouldDispatch(event: nil))
        #expect(ImageEditorHistoryCommandDispatchGate.shouldDispatch(event: nil))
    }

    @Test func onePhysicalNewLayerShortcutCreatesOnlyOneLayer() {
        ImageEditorNewLayerCommandDispatchGate.reset()
        defer { ImageEditorNewLayerCommandDispatchGate.reset() }

        let image = NSImage(size: NSSize(width: 32, height: 24))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let initialLayerCount = viewModel.document.layers.count
        let firstEvent = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 7,
            eventNumber: 301,
            timestamp: 45,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 45
        )
        let secondEvent = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 7,
            eventNumber: 302,
            timestamp: 45.2,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 45
        )

        func dispatchNewLayer(event: ImageEditorKeyboardShortcutEventSignature?) {
            guard ImageEditorNewLayerCommandDispatchGate.shouldDispatch(
                event: event
            ) else { return }
            viewModel.addLayer()
        }

        dispatchNewLayer(event: firstEvent)
        dispatchNewLayer(event: firstEvent)
        #expect(viewModel.document.layers.count == initialLayerCount + 1)

        dispatchNewLayer(event: secondEvent)
        #expect(viewModel.document.layers.count == initialLayerCount + 2)

        dispatchNewLayer(event: nil)
        dispatchNewLayer(event: nil)
        #expect(viewModel.document.layers.count == initialLayerCount + 4)
    }

    @Test func penPointConstraintUsesNearestFortyFiveDegreeDirectionAndCanvasBoundary() {
        let horizontal = ImageEditorPenPointGeometry.constrainedPoint(
            from: CGPoint(x: 50, y: 50),
            toward: CGPoint(x: 90, y: 60),
            canvasSize: CGSize(width: 100, height: 100)
        )
        #expect(abs(horizontal.y - 50) < 0.000_001)
        #expect(abs(hypot(horizontal.x - 50, horizontal.y - 50) - hypot(40, 10)) < 0.000_001)

        let diagonalAtBoundary = ImageEditorPenPointGeometry.constrainedPoint(
            from: CGPoint(x: 90, y: 90),
            toward: CGPoint(x: 130, y: 110),
            canvasSize: CGSize(width: 100, height: 100)
        )
        #expect(abs(diagonalAtBoundary.x - 100) < 0.000_001)
        #expect(abs(diagonalAtBoundary.y - 100) < 0.000_001)

        let unchanged = ImageEditorPenPointGeometry.constrainedPoint(
            from: CGPoint(x: 24, y: 36),
            toward: CGPoint(x: 24, y: 36),
            canvasSize: CGSize(width: 100, height: 100)
        )
        #expect(unchanged == CGPoint(x: 24, y: 36))
    }

    @Test func commandClickFinishesOnlyAnExistingPendingPenPath() {
        #expect(ImageEditorPendingPenPointerFinishPolicy.shouldFinishOpenPath(
            hasPendingPath: true,
            modifierFlags: .command
        ))
        #expect(!ImageEditorPendingPenPointerFinishPolicy.shouldFinishOpenPath(
            hasPendingPath: false,
            modifierFlags: .command
        ))
        for modifierFlags: NSEvent.ModifierFlags in [
            [],
            [.command, .shift],
            [.command, .option],
            [.command, .control]
        ] {
            #expect(!ImageEditorPendingPenPointerFinishPolicy.shouldFinishOpenPath(
                hasPendingPath: true,
                modifierFlags: modifierFlags
            ))
        }
    }

    @Test func returnAndKeypadEnterFinishOnlyUnmodifiedPendingPenPaths() {
        for keyCode: UInt16 in [36, 76] {
            #expect(ImageEditorPendingPenFinishKeyPolicy.matches(
                keyCode: keyCode,
                modifierFlags: []
            ))
            #expect(!ImageEditorPendingPenFinishKeyPolicy.matches(
                keyCode: keyCode,
                modifierFlags: .shift
            ))
            #expect(!ImageEditorPendingPenFinishKeyPolicy.matches(
                keyCode: keyCode,
                modifierFlags: .command
            ))
        }
        #expect(!ImageEditorPendingPenFinishKeyPolicy.matches(
            keyCode: 53,
            modifierFlags: []
        ))
    }

    @Test func unfinishedPenPointerSequenceOwnsHistoryUntilMouseUp() {
        #expect(ImageEditorPendingPenPointerPolicy.ownsUncommittedPoint(
            tool: .pen,
            isPointerSequenceActive: true,
            isMovingPathAnchor: false
        ))
        #expect(!ImageEditorPendingPenPointerPolicy.ownsUncommittedPoint(
            tool: .pen,
            isPointerSequenceActive: false,
            isMovingPathAnchor: false
        ))
        #expect(!ImageEditorPendingPenPointerPolicy.ownsUncommittedPoint(
            tool: .pen,
            isPointerSequenceActive: true,
            isMovingPathAnchor: true
        ))
        #expect(!ImageEditorPendingPenPointerPolicy.ownsUncommittedPoint(
            tool: .brush,
            isPointerSequenceActive: true,
            isMovingPathAnchor: false
        ))
    }

    @Test
    func clearHistoryKeepsCurrentStateAndDropsUndoRedoSnapshots() throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 16
        viewModel.drawBrush(points: [CGPoint(x: 8, y: 8), CGPoint(x: 70, y: 50)])
        let paintedData = try #require(viewModel.currentImage.qingtuPNGData())
        let paintedLayerFrame = try #require(viewModel.document.selectedLayer?.frame)

        viewModel.undo()
        #expect(viewModel.canRedo)
        viewModel.redo()
        #expect(viewModel.canUndo)
        #expect(viewModel.document.history.count > 1)

        viewModel.clearHistoryStates()

        let clearedData = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(clearedData == paintedData)
        #expect(viewModel.document.selectedLayer?.frame == paintedLayerFrame)
        #expect(viewModel.document.history.count == 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.currentState"))
        #expect(!viewModel.canUndo)
        #expect(!viewModel.canRedo)
        #expect(viewModel.historySnapshots.count == 1)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.historyCleared"))
    }

    @Test
    func namedHistorySnapshotsRestoreDocumentStateAndSurviveHistoryClear() throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let cleanData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.createHistorySnapshot()
        let snapshot = try #require(viewModel.namedHistorySnapshots.first)
        #expect(snapshot.name == L10n.format("imageEditor.history.snapshotName", 1))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.historySnapshotCreated", snapshot.name))

        viewModel.renameHistorySnapshot(snapshot.id, to: "Clean Base")
        let renamedSnapshot = try #require(viewModel.namedHistorySnapshots.first)
        #expect(renamedSnapshot.name == "Clean Base")

        viewModel.clearHistoryStates()
        #expect(viewModel.namedHistorySnapshots.count == 1)

        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 16
        viewModel.drawBrush(points: [CGPoint(x: 8, y: 8), CGPoint(x: 70, y: 50)])
        let paintedData = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(paintedData != cleanData)

        viewModel.restoreHistorySnapshot(renamedSnapshot.id)

        let restoredData = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(restoredData == cleanData)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.snapshotRestore"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.historySnapshotRestored", "Clean Base"))
        #expect(viewModel.canUndo)

        viewModel.undo()
        let undoneData = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(undoneData == paintedData)

        viewModel.deleteHistorySnapshot(renamedSnapshot.id)
        #expect(viewModel.namedHistorySnapshots.isEmpty)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.historySnapshotDeleted", "Clean Base"))
    }

    @Test
    func deletingSelectedHistoryStepTruncatesThatStepAndLaterOperations() throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.foregroundColor = .systemPink
        viewModel.drawBrush(points: [CGPoint(x: 8, y: 8), CGPoint(x: 34, y: 24)])
        let firstStrokeData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.foregroundColor = .systemGreen
        viewModel.drawBrush(points: [CGPoint(x: 40, y: 30), CGPoint(x: 72, y: 52)])
        let secondStrokeData = try #require(viewModel.currentImage.qingtuPNGData())
        let originalHistoryCount = viewModel.document.history.count
        let selectedEntry = try #require(viewModel.document.history.last)

        viewModel.selectHistoryEntry(selectedEntry.id)
        #expect(viewModel.canTruncateSelectedHistory)
        viewModel.truncateSelectedHistory()

        #expect(viewModel.currentImage.qingtuPNGData() == firstStrokeData)
        #expect(viewModel.document.history.count == originalHistoryCount - 1)
        #expect(viewModel.selectedHistoryEntryID == viewModel.document.history.last?.id)
        #expect(viewModel.canUndo)

        viewModel.undo()
        #expect(viewModel.currentImage.qingtuPNGData() == secondStrokeData)
        #expect(viewModel.document.history.count == originalHistoryCount)
    }

    @Test
    func historyQueryFiltersByLocalizedTitleWithoutChangingDocumentHistory() throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let originalHistory = viewModel.document.history

        viewModel.addLayer()
        viewModel.historyQuery = "图层"

        #expect(viewModel.filteredHistoryEntries.count == 1)
        #expect(viewModel.filteredHistoryEntries.first?.title == L10n.text("imageEditor.history.layerNew"))
        #expect(viewModel.document.history.count == originalHistory.count + 1)

        viewModel.historyQuery = ""
        #expect(viewModel.filteredHistoryEntries.count == viewModel.document.history.count)
    }

    @Test
    func historyQueryFiltersNamedSnapshotsWithoutChangingSnapshotState() throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.createHistorySnapshot()
        let snapshot = try #require(viewModel.namedHistorySnapshots.first)
        viewModel.renameHistorySnapshot(snapshot.id, to: "Clean Base")
        let originalSnapshotIDs = viewModel.namedHistorySnapshots.map(\.id)

        viewModel.historyQuery = "clean"
        #expect(viewModel.filteredHistorySnapshots.map(\.id) == originalSnapshotIDs)
        #expect(viewModel.filteredHistoryEntries.isEmpty)
        #expect(viewModel.document.history.count == 1)

        viewModel.historyQuery = "missing"
        #expect(viewModel.filteredHistorySnapshots.isEmpty)
        #expect(viewModel.namedHistorySnapshots.map(\.id) == originalSnapshotIDs)
    }

    @Test
    func cropSelectsTheEntireNewCanvas() throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        viewModel.document.selection = .rectangle(CGRect(x: 2, y: 3, width: 18, height: 16))

        viewModel.crop(to: CGRect(x: 20, y: 10, width: 60, height: 50))

        #expect(viewModel.document.canvasSize == CGSize(width: 60, height: 50))
        let selection = try #require(viewModel.document.selection)
        #expect(selection == .fullCanvas(size: CGSize(width: 60, height: 50)))
    }

    @Test
    func editorWindowResolvesEveryDeclaredMenuShortcut() {
        let command = NSEvent.ModifierFlags.command
        let option = NSEvent.ModifierFlags.option
        let shift = NSEvent.ModifierFlags.shift
        let cases: [(String, NSEvent.ModifierFlags, UInt16?, ImageEditorKeyboardShortcutAction)] = [
            ("n", command, nil, .newCanvas),
            ("o", command, nil, .openProject),
            ("s", command, nil, .saveProject),
            ("s", [command, option, shift], nil, .export),
            ("z", command, nil, .undo),
            ("z", option, nil, .undo),
            ("z", [command, option], nil, .undo),
            ("z", [command, shift], nil, .redo),
            ("x", command, nil, .cutSelectionClipboard),
            ("c", command, nil, .copySelectionClipboard),
            ("c", [command, shift], nil, .copyMergedClipboard),
            ("c", [command, option, shift], nil, .copySelectedLayersClipboard),
            ("v", command, nil, .pasteClipboardLayer),
            ("v", [command, shift], nil, .pasteClipboardIntoSelection),
            ("v", [command, option, shift], nil, .pasteClipboardInPlaceLayer),
            ("t", command, nil, .toggleTransformControls),
            ("", shift, 96, .openSelectionFill),
            ("", option, 51, .fillSelection),
            ("", [option, shift], 51, .fillSelectionPreservingTransparency),
            ("", command, 51, .fillSelectionBackground),
            ("", [command, shift], 51, .fillSelectionBackgroundPreservingTransparency),
            ("", [command, option], 51, .fillSelectionHistory),
            ("", [command, option, shift], 51, .fillSelectionHistoryPreservingTransparency),
            ("", [], 51, .clearSelectionPixels),
            ("i", [command, option], nil, .resizeImage),
            ("c", [command, option], nil, .resizeCanvas),
            ("l", command, nil, .levels),
            ("m", command, nil, .curves),
            ("b", command, nil, .colorBalance),
            ("u", command, nil, .hueSaturation),
            ("u", [command, shift], nil, .desaturate),
            ("i", command, nil, .invertPixels),
            ("l", [command, shift], nil, .autoLevels),
            ("l", [command, option, shift], nil, .autoContrast),
            ("b", [command, shift], nil, .autoColor),
            ("n", [command, shift], nil, .newLayer),
            ("j", command, nil, .duplicateSelectionOrLayer),
            ("j", [command, shift], nil, .cutSelectionToLayer),
            ("g", command, nil, .groupSelectedLayer),
            ("g", [command, shift], nil, .ungroupSelectedLayers),
            ("e", command, nil, .mergeDown),
            ("e", [command, option, shift], nil, .stampVisible),
            ("e", [command, shift], nil, .mergeVisible),
            ("]", [command, shift], nil, .layerTop),
            ("]", command, nil, .layerUp),
            ("[", command, nil, .layerDown),
            ("[", [command, shift], nil, .layerBottom),
            ("a", [command, option], nil, .selectAllLayers),
            ("a", command, nil, .selectAll),
            ("d", command, nil, .clearSelection),
            ("d", [command, shift], nil, .reselectSelection),
            ("i", [command, shift], nil, .invertSelection),
            ("d", [command, option], nil, .featherSelection),
            ("f", command, nil, .applyLastFilter),
            ("r", command, nil, .toggleRulers),
            (";", command, nil, .toggleGuides),
            (";", [command, shift], nil, .toggleGuideSnapping),
            (";", [command, option], nil, .toggleGuidesLocked),
            ("'", command, nil, .toggleGrid),
            ("=", [command, shift], nil, .zoomIn),
            ("-", command, nil, .zoomOut),
            ("+", option, nil, .zoomIn),
            ("=", option, nil, .zoomIn),
            ("=", [option, shift], nil, .zoomIn),
            ("-", option, nil, .zoomOut),
            ("1", command, nil, .actualPixels),
            ("0", command, nil, .fitOnScreen),
            ("", [], 48, .toggleWorkspaceChrome),
            ("", shift, 48, .toggleRightDock),
            ("", [], 96, .showBrushSummary),
            ("", [], 97, .showColorSummary),
            ("", [], 98, .showLayersPanel),
            ("", [], 100, .showInfoSummary),
        ]

        for (key, flags, keyCode, expected) in cases {
            #expect(
                ImageEditorKeyboardShortcutAction.resolve(
                    charactersIgnoringModifiers: key,
                    modifierFlags: flags,
                    keyCode: keyCode
                ) == expected
            )
        }

        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "s",
                modifierFlags: [shift, option],
                activeTool: .dodge
            ) == .toneRange(.shadows)
        )
        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "m",
                modifierFlags: [shift, option],
                activeTool: .burn
            ) == .toneRange(.midtones)
        )
        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "h",
                modifierFlags: [shift, option],
                activeTool: .move
            ) == nil
        )
        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "s",
                modifierFlags: [shift, option],
                activeTool: .sponge
            ) == .spongeMode(.saturate)
        )
        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "d",
                modifierFlags: [shift, option],
                activeTool: .sponge
            ) == .spongeMode(.desaturate)
        )

        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "a",
                modifierFlags: []
            ) == nil
        )
    }

    @Test
    func livePointerMoveOwnsKeyboardCommandsUntilItEnds() {
        #expect(
            ImageEditorLiveMoveShortcutPolicy.disposition(
                for: .saveProject,
                hasActiveLayerMoveTransaction: true
            ) == .ignore
        )
        #expect(
            ImageEditorLiveMoveShortcutPolicy.disposition(
                for: .pasteClipboardLayer,
                hasActiveLayerMoveTransaction: true
            ) == .ignore
        )
        #expect(
            ImageEditorLiveMoveShortcutPolicy.disposition(
                for: .zoomIn,
                hasActiveLayerMoveTransaction: true
            ) == .ignore
        )
        #expect(
            ImageEditorLiveMoveShortcutPolicy.disposition(
                for: .undo,
                hasActiveLayerMoveTransaction: true
            ) == .cancelMove
        )
        #expect(
            ImageEditorLiveMoveShortcutPolicy.disposition(
                for: .redo,
                hasActiveLayerMoveTransaction: true
            ) == .cancelMove
        )
        #expect(
            ImageEditorLiveMoveShortcutPolicy.disposition(
                for: .saveProject,
                hasActiveLayerMoveTransaction: false,
                hasActivePathAnchorMoveTransaction: true
            ) == .ignore
        )
        #expect(
            ImageEditorLiveMoveShortcutPolicy.disposition(
                for: .undo,
                hasActiveLayerMoveTransaction: false,
                hasActivePathAnchorMoveTransaction: true
            ) == .cancelMove
        )
        #expect(
            ImageEditorLiveMoveShortcutPolicy.disposition(
                for: .redo,
                hasActiveLayerMoveTransaction: false,
                hasActivePathAnchorMoveTransaction: true
            ) == .cancelMove
        )
        #expect(
            ImageEditorLiveMoveShortcutPolicy.disposition(
                for: .saveProject,
                hasActiveLayerMoveTransaction: false,
                hasActivePathAnchorMoveTransaction: false
            ) == .perform
        )
        #expect(
            !ImageEditorLiveMoveShortcutPolicy.allowsDirectShortcut(
                hasActiveLayerMoveTransaction: true
            )
        )
        #expect(
            !ImageEditorLiveMoveShortcutPolicy.allowsDirectShortcut(
                hasActiveLayerMoveTransaction: false,
                hasActivePathAnchorMoveTransaction: true
            )
        )
        #expect(
            ImageEditorLiveMoveShortcutPolicy.allowsDirectShortcut(
                hasActiveLayerMoveTransaction: false,
                hasActivePathAnchorMoveTransaction: false
            )
        )
        #expect(
            !ImageEditorLiveMoveShortcutPolicy.allowsDirectShortcut(
                hasActiveLayerMoveTransaction: false,
                hasActivePathAnchorMoveTransaction: false,
                isTextInputActive: true
            )
        )
    }

    @Test
    func keyboardShortcutWindowRegistryTracksEveryMountedCoordinatorPerWindow() {
        ImageEditorKeyboardShortcutWindowRegistry.reset()
        defer { ImageEditorKeyboardShortcutWindowRegistry.reset() }
        let window = NSObject()
        let firstCoordinator = NSObject()
        let latestCoordinator = NSObject()

        ImageEditorKeyboardShortcutWindowRegistry.register(
            coordinator: firstCoordinator,
            for: window
        )
        #expect(ImageEditorKeyboardShortcutWindowRegistry.isRegistered(
            coordinator: firstCoordinator,
            for: window
        ))

        ImageEditorKeyboardShortcutWindowRegistry.register(
            coordinator: latestCoordinator,
            for: window
        )
        #expect(ImageEditorKeyboardShortcutWindowRegistry.isRegistered(
            coordinator: firstCoordinator,
            for: window
        ))
        #expect(ImageEditorKeyboardShortcutWindowRegistry.isRegistered(
            coordinator: latestCoordinator,
            for: window
        ))
        let newestFirst = ImageEditorKeyboardShortcutWindowRegistry
            .registeredCoordinatorsNewestFirst(for: window)
        #expect(newestFirst.count == 2)
        #expect(newestFirst[0] === latestCoordinator)
        #expect(newestFirst[1] === firstCoordinator)

        ImageEditorKeyboardShortcutWindowRegistry.unregister(
            coordinator: firstCoordinator,
            from: window
        )
        #expect(!ImageEditorKeyboardShortcutWindowRegistry.isRegistered(
            coordinator: firstCoordinator,
            for: window
        ))
        #expect(ImageEditorKeyboardShortcutWindowRegistry.isRegistered(
            coordinator: latestCoordinator,
            for: window
        ))
        ImageEditorKeyboardShortcutWindowRegistry.unregister(
            coordinator: latestCoordinator,
            from: window
        )
        #expect(!ImageEditorKeyboardShortcutWindowRegistry.isRegistered(
            coordinator: latestCoordinator,
            for: window
        ))
    }

    @Test
    func keyboardShortcutWindowRegistryKeepsEveryMountedCoordinatorEligible() {
        ImageEditorKeyboardShortcutWindowRegistry.reset()
        defer { ImageEditorKeyboardShortcutWindowRegistry.reset() }
        let window = NSObject()
        let mountedCoordinator = NSObject()
        let transientReplacement = NSObject()

        ImageEditorKeyboardShortcutWindowRegistry.register(
            coordinator: mountedCoordinator,
            for: window
        )
        ImageEditorKeyboardShortcutWindowRegistry.register(
            coordinator: transientReplacement,
            for: window
        )
        #expect(ImageEditorKeyboardShortcutWindowRegistry.isRegistered(
            coordinator: mountedCoordinator,
            for: window
        ))
        #expect(ImageEditorKeyboardShortcutWindowRegistry.isRegistered(
            coordinator: transientReplacement,
            for: window
        ))

        ImageEditorKeyboardShortcutWindowRegistry.unregister(
            coordinator: transientReplacement,
            from: window
        )

        #expect(ImageEditorKeyboardShortcutWindowRegistry.isRegistered(
            coordinator: mountedCoordinator,
            for: window
        ))
        #expect(!ImageEditorKeyboardShortcutWindowRegistry.isRegistered(
            coordinator: transientReplacement,
            for: window
        ))
    }

    @Test
    func keyboardShortcutEventWindowPolicyAcceptsKeyWindowEventsWithoutAnAttachedWindow() {
        let editorWindow = NSObject()
        let otherWindow = NSObject()

        #expect(ImageEditorKeyboardShortcutEventWindowPolicy.belongsToEditorWindow(
            eventWindow: editorWindow,
            eventWindowNumber: 42,
            editorWindow: editorWindow,
            editorWindowNumber: 42,
            keyWindow: otherWindow
        ))
        #expect(ImageEditorKeyboardShortcutEventWindowPolicy.belongsToEditorWindow(
            eventWindow: nil,
            eventWindowNumber: 42,
            editorWindow: editorWindow,
            editorWindowNumber: 42,
            keyWindow: otherWindow
        ))
        #expect(ImageEditorKeyboardShortcutEventWindowPolicy.belongsToEditorWindow(
            eventWindow: nil,
            eventWindowNumber: 0,
            editorWindow: editorWindow,
            editorWindowNumber: 42,
            keyWindow: editorWindow
        ))
        #expect(!ImageEditorKeyboardShortcutEventWindowPolicy.belongsToEditorWindow(
            eventWindow: otherWindow,
            eventWindowNumber: 7,
            editorWindow: editorWindow,
            editorWindowNumber: 42,
            keyWindow: editorWindow
        ))
        #expect(!ImageEditorKeyboardShortcutEventWindowPolicy.belongsToEditorWindow(
            eventWindow: nil,
            eventWindowNumber: 0,
            editorWindow: editorWindow,
            editorWindowNumber: 42,
            keyWindow: otherWindow
        ))
    }

    @Test
    func historyPanelUsesSearchFieldAndFilteredEntries() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("image-editor-history-search-field"))
        #expect(source.contains("image-editor-history-search-clear"))
        #expect(source.contains("ForEach(viewModel.filteredHistoryEntries)"))
        #expect(source.contains("ForEach(viewModel.filteredHistorySnapshots)"))
        #expect(source.contains("imageEditor.history.searchPlaceholder"))
    }

    private func makePixelShortcutViewModel() throws -> ImageEditorViewModel {
        let image = try #require(NSImage.rendered(size: NSSize(width: 24, height: 18)) { rect in
            NSColor.red.setFill()
            rect.fill()
            NSColor.blue.setFill()
            CGRect(x: rect.midX, y: 0, width: rect.width / 2, height: rect.height).fill()
        })
        let model = ImageEditorViewModel(sourceName: "pixel-shortcut.png", image: image) { _ in }
        let sourceID = try #require(model.document.layers.first?.id)
        model.selectLayer(sourceID)
        try #require(model.canConvertBackgroundToLayer)
        model.convertBackgroundToLayer()
        return model
    }

    private func testImage(color: NSColor, size: NSSize) -> NSImage {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(color.usingColorSpace(.deviceRGB)?.cgColor ?? NSColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        return NSImage(cgImage: context.makeImage()!, size: size)
    }
}
